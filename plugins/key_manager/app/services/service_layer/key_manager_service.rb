require 'fog/key_manager/openstack/models/secret'

module ServiceLayer

  class KeyManagerService < Core::ServiceLayer::Service
    include Core::ServiceLayer::FogDriver::ClientHelper

    attr_reader :service
    
    def available?(action_name_sym=nil)
      not current_user.service_url('key-manager',region: region).nil?
    end

    def secrets(filter={})
      ::KeyManager::Secret.create_secrets(service.secrets.all(filter))
    end

    def secret(uuid)
      secret_attr = service.secrets.get(uuid).attributes
      secret_metadata = service.get_secret_metadata(uuid).data.fetch(:body, {})
      secret_payload = service.get_secret_payload(uuid).data.fetch(:body, "")
      ::KeyManager::Secret.new(secret_attr.merge({service: service, metadata: secret_metadata, payload: secret_payload}))
    end

    def new_secret(attr)
      ::KeyManager::Secret.new(attr.merge({service: service}))
    end

    def service
      @service ||= ::Fog::KeyManager::OpenStack.new(auth_params)
    end

  end
end