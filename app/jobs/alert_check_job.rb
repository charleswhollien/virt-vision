# Background job to check alert conditions and send notifications
class AlertCheckJob < ApplicationJob
  queue_as :default

  def perform
    check_vm_alerts
    check_host_alerts
  end

  private

  def check_vm_alerts
    Alert.enabled.where.not(vm_id: nil).find_each do |alert|
      next unless alert.vm

      should_trigger = case alert.condition_type
                       when "vm_stopped"
                         alert.vm.status == "stopped"
                       when "vm_crashed"
                         alert.vm.status == "crashed"
                       when "high_cpu"
                         # Would need CPU usage tracking
                         false
                       when "high_memory"
                         alert.vm.memory_usage_percent > alert.threshold.to_f
                       else
                         false
                       end

      if should_trigger
        NotificationService.send_alert(alert, alert.vm)
      end
    end
  end

  def check_host_alerts
    Alert.enabled.where.not(host_id: nil).find_each do |alert|
      next unless alert.host

      should_trigger = case alert.condition_type
                       when "host_offline"
                         alert.host.status == "offline" || alert.host.status == "error"
                       when "high_cpu"
                         alert.host.cpu_total > alert.threshold.to_f
                       when "high_memory"
                         # Would need memory tracking
                         false
                       else
                         false
                       end

      if should_trigger
        NotificationService.send_alert(alert, alert.host)
      end
    end
  end
end
