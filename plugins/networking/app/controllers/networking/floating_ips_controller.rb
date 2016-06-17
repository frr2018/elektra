module Networking
  class FloatingIpsController < DashboardController
    def index
      @floating_ips = services.networking.project_floating_ips(@scoped_project_id)
    end
    
    def new
      @floating_networks = services.networking.networks('router:external' => true)
      @floating_ip = Networking::FloatingIp.new(nil)
      if @floating_networks.length==1
        @floating_ip.floating_network_id = @floating_networks.first.id
      end
    end
    
    def create
      @floating_networks = services.networking.networks('router:external' => true)
      @floating_ip = services.networking.new_floating_ip(params[:floating_ip])
      @floating_ip.tenant_id=@scoped_project_id
      if @floating_ip.save
        render action: :create
      else
        render action: :new
      end
    end
    
    def destroy
      if services.networking.delete_floating_ip(params[:id])
        @deleted=true
        flash.now[:notice] = "Floating IP deleted!"
      else
        @deleted=false
        flash.now[:error] = "Could not delete floating IP."
      end
    end
  end
end
