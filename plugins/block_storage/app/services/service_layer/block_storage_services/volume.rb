# frozen_string_literal: true

module ServiceLayer
  module BlockStorageServices
    module Volume

      def volume_map
        @volume_map ||= class_map_proc(BlockStorage::Volume)
      end

      def volumes(filter = {})
        elektron_volumes.get('volumes', filter).map_to(
          'body.volumes', &volume_map
        )
      end

      def volumes_detail(filter = {})
        elektron_volumes.get('volumes/detail', filter).map_to(
          'body.volumes', &volume_map
        )
      end

      def find_volume!(id)
        return nil if id.blank?
        elektron_volumes.get("volumes/#{id}").map_to('body.volume', &volume_map)
      end

      def find_volume(id)
        find_volume!(id)
      rescue Elektron::Errors::ApiResponse => _e
        nil
      end

      def new_volume(params = {})
        volume_map.call(params)
      end

      ################## MODEL INTERFACE METHODS ####################
      def create_volume(params = {})
        elektron_volumes.post('volumes') do
          { volume: params }
        end.body['volume']
      end

      def update_volume(id, params = {})
        elektron_volumes.put("volumes/#{id}") do
          { volume: params }
        end.body['volume']
      end

      def delete_volume(id)
        elektron_volumes.delete("volumes/#{id}")
      end

      def reset_volume_status(id, status = {})
        status = status.with_indifferent_access if status.is_a?(Hash)
        elektron_volumes.post("volumes/#{id}/action") do
          {
            'os-reset_status' => {
              'status': status['status'],
              'attach_status': status['attach_status'],
              'migration_status': status['migration_status']
            }
          }
        end
      end

      def extend_volume_size(id, size)
        elektron_volumes.post("volumes/#{id}/action") do
          {
            'os-extend': {
              'new_size': size
            }
          }
        end
      end

      def force_delete_volume(id)
        elektron_volumes.post("volumes/#{id}/action") do
          { 'os-force_delete' => {} }
        end
      end

      def attach(volume_id, server_id, device = nil)
        # block storage api does not support empty device option.
        # In this case use attach method frm compute which accepts blank
        # device option.
        if device.nil? && service_manager.compute.available?
          return service_manager.compute.attach_volume(
            volume_id, server_id, device
          )
        end

        elektron_volumes.post("volumes/#{volume_id}/action") do
          {
            "os-attach": {
              "instance_uuid": server_id,
              "mountpoint": device
            }
          }
        end
      end

      def detach(volume_id, attachment_id)
        elektron_volumes.post("volumes/#{volume_id}/action") do
          {
            "os-detach": {
              "attachment_id": attachment_id
            }
          }
        end
      end
    end
  end
end
