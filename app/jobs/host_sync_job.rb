# Background job to sync host status and VM information
class HostSyncJob < ApplicationJob
  queue_as :default

  def perform(host_id = nil)
    hosts = host_id ? Host.where(id: host_id) : Host.all

    hosts.find_each do |host|
      sync_host(host)
    end
  end

  private

  def sync_host(host)
    Rails.logger.info("Syncing host: #{host.name}")

    service = LibvirtService.new(host)

    # Test connection and update status
    if service.test_connection
      host.update!(status: "online", last_polled_at: Time.current)

      # Get host stats
      stats = service.get_host_stats
      host.update!(
        cpu_total: stats[:cpu_usage_percent],
        memory_total: stats[:memory_total_kb] / 1024
      )

      # Sync VMs
      sync_vms(host, service)
    else
      host.update!(status: "offline")
    end
  rescue LibvirtService::ConnectionError => e
    Rails.logger.error("Connection error for #{host.name}: #{e.message}")
    host.update!(status: "error")
  rescue => e
    Rails.logger.error("Error syncing host #{host.name}: #{e.message}")
    host.update!(status: "error")
  end

  def sync_vms(host, service)
    vm_data_list = service.list_vms

    vm_data_list.each do |vm_data|
      vm = host.vms.find_or_initialize_by(uuid: vm_data[:uuid])
      vm.assign_attributes(vm_data)
      vm.last_updated_at = Time.current
      vm.save!
    end

    # Mark VMs that no longer exist on the host
    current_uuids = vm_data_list.pluck(:uuid)
    host.vms.where.not(uuid: current_uuids).each do |vm|
      vm.update!(status: "crashed") # VM was removed or crashed
    end
  end
end
