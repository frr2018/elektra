module Core
  module ServiceUser
    class Base
      @@service_user_mutex = Mutex.new
      
      # # delegate some methods to auth_users
      delegate :token, :token_expired?, :token_expires_at, :domain_id, :domain_name, to: :@auth_user
      
      # Class methods    
      class << self
        def load(params={})
          scope_domain = params[:scope_domain]
          return nil if scope_domain.nil?

          # puts ">>>>>Rails.configuration.keystone_endpoint: #{Rails.configuration.keystone_endpoint}"
          # puts ">>>>>Rails.configuration.default_region: #{Rails.configuration.default_region}"
          # puts ">>>>>Rails.configuration.service_user_id: #{Rails.configuration.service_user_id}"
          # puts ">>>>>Rails.configuration.service_user_password: #{Rails.configuration.service_user_password}"
          # puts ">>>>>Rails.configuration.service_user_domain_name: #{Rails.configuration.service_user_domain_name}"
          # puts ">>>>>scope_domain: #{scope_domain}"
    
          @@service_user_mutex.synchronize do
            @service_users ||= {}
          
            service_user = @service_users[scope_domain]
            if service_user.nil?
              @service_users[scope_domain] = self.new(
                params[:user_id],
                params[:password],
                params[:user_domain],
                scope_domain
              )
            end
          end
          
          @service_users[scope_domain]
        end
      end
      
      def token
        @driver.auth_token
      end
      
      def initialize(user_id,password,user_domain_name,scope_domain)
        @user_id = user_id
        @password = password
        @user_domain_name = user_domain_name
        @scope_domain = scope_domain
        authenticate
      end
      
      def authenticate
        @auth_user = begin
          MonsoonOpenstackAuth.api_client.auth_user(
            @user_id,
            @password,
            domain_name: @user_domain_name,
            scoped_token: {domain: {name: @scope_domain} } 
          )
        rescue
          begin
            MonsoonOpenstackAuth.api_client.auth_user(
              @user_id,
              @password,
              domain_name: @user_domain_name,
              scoped_token: {domain: {id: @scope_domain}}
            )
          rescue MonsoonOpenstackAuth::Authentication::MalformedToken => e
            raise ::Core::ServiceUser::Errors::AuthenticationError.new("Could not authenticate service user. Please check permissions on #{@scope_domain} for service user #{@user_id}")
          end
        end
        
        @driver = ::Core::ServiceUser::Driver.new({
          # openstack_auth_url:   ::Core.keystone_auth_endpoint,
          # openstack_region:      Rails.application.config.default_region,#::Core.locate_region(@auth_user),
          # openstack_user_domain: Rails.application.config.service_user_domain_name,
          # openstack_username:    Rails.application.config.service_user_id,
          # openstack_api_key:     Rails.application.config.service_user_password,
          # openstack_domain_name: scope_domain
          openstack_auth_url:   ::Core.keystone_auth_endpoint,
          openstack_region:     Core.locate_region(@auth_user),
          openstack_auth_token: @auth_user.token,
        })
      end
      
      # execute driver method. Catch 401 errors (token invalid -> expired or revoked)
      def driver_method(method_sym,map,*arguments)
        if map 
          @driver.map_to(Core::ServiceLayer::Model).send(method_sym,*arguments)
        else
          @driver.send(method_sym,*arguments)
        end  
      rescue Core::ServiceLayer::Errors::ApiError => e
        # reauthenticate
        authenticate
        # and try again 
        if map 
          @driver.map_to(Core::ServiceLayer::Model).send(method_sym,*arguments)
        else
          @driver.send(method_sym,*arguments)
        end 
      end
        
      
      def find_user(user_id)
        driver_method(:get_user,true,user_id)
      end
      
      def roles(filter={})
        driver_method(:roles,true,filter)
      end
      
      def role_assignments(filter={})
        driver_method(:role_assignments,true,filter)
      end
      
      def find_role_by_name(name)
        roles.select { |r| r.name==name }.first
      end
      
      def find_project_by_name_or_id(name_or_id)
        project = driver_method(:get_project,true,name_or_id) rescue nil
        unless project
          project = driver_method(:projects,true,{domain_id: self.domain_id, name: name_or_id}).first rescue nil
        end
        project
      end
      
      # def find_project(id)
      #   driver_method(:get_project,true,id)
      # end
      
      def grant_user_domain_member_role(user_id,role_name)
        role = self.find_role_by_name(role_name)
        driver_method(:grant_domain_user_role,false,self.domain_id, user_id, role.id)
      end
      
      # A special case of list_scope_admins that returns a list of cloud admins.
      # This logic is hardcoded for now since the concept of a cloud admin will only
      # be introduced formally in the next Keystone release (Mitaka).
      def list_cloud_admins
        unless @admin_domain_id
          domain_name = ENV.fetch('MONSOON_OPENSTACK_CLOUDADMIN_DOMAIN', 'monsooncc')
          @admin_domain_id = driver_method(:domains,true, {name: domain_name}).first.id
        end

        return list_scope_admins({ domain_id: @admin_domain_id })
      end

      # Returns admins for the given scope (e.g. project_id: PROJECT_ID, domain_id: DOMAIN_ID)
      # This method looks recursively for project, parent_projects and domain admins until it finds at least one.
      # It should always return a non empty list (at least the domain admins).
      def list_scope_admins(scope={})
        role = self.find_role_by_name('admin') rescue nil
        list_scope_assigned_users(scope.merge(role: role))
      end
      
      def list_scope_assigned_users!(options={})
        list_scope_assigned_users(options.merge(raise_error: true))  
      end
      
      # Returns assigned users for the given scope and role (e.g. project_id: PROJECT_ID, domain_id: DOMAIN_ID, role: ROLE)
      # This method looks recursively for assigned users of project, parent_projects and domain. 
      def list_scope_assigned_users(options={})
        admins      = []
        project_id  = options[:project_id]
        domain_id   = options[:domain_id]
        role        = options[:role]
        raise_error = options[:raise_error]
        
        # do nothing if role is nil
        return admins if role.nil?
        
        begin
        
          if project_id # project_id is presented
            # get role_assignments for this project_id
            role_assignments = self.role_assignments("scope.project.id"=>project_id,"role.id"=>role.id) #rescue []
            # load users (not very performant but there is no other option to get users by ids)
            role_assignments.collect{|r| admins << self.find_user(r.user["id"])  }
          
            if admins.length==0 # no admins for this project_id found
              # load project
              project = self.find_project(project_id) rescue nil
              if project 
                # try to get admins recursively by parent_id 
                admins = list_scope_assigned_users(project_id: project.parent_id, domain_id: project.domain_id, role: role)
              end  
            end
          elsif domain_id # project_id is nil but domain_id is presented
            # get role_assignments for this domain_id
            role_assignments = self.role_assignments("scope.domain.id"=>domain_id,"role.id"=>role.id, effective: true) #rescue []
            # load users
            role_assignments.collect{|r|  admins << self.find_user(r.user["id"]) }       
          end
        rescue => e
          raise e if raise_error
        end
        
        return admins.delete_if {|a| a.id == nil} # delete crap
      end
    end
  end
end