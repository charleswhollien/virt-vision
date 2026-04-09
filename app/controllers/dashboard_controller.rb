class DashboardController < ApplicationController
  def show
    @hosts = Host.all
    @vms = Vm.includes(:host).all
    @recent_alerts = Alert.includes(:host, :vm).order(created_at: :desc).limit(10)

    # Summary stats
    @stats = {
      total_hosts: @hosts.count,
      online_hosts: @hosts.where(status: "online").count,
      total_vms: @vms.count,
      running_vms: @vms.where(status: "running").count,
      paused_vms: @vms.where(status: "paused").count,
      stopped_vms: @vms.where(status: "stopped").count
    }
  end
end
