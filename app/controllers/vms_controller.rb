class VmsController < ApplicationController
  before_action :require_admin!, except: [:index, :show]
  before_action :set_vm, only: [:show, :start, :shutdown, :reboot, :pause, :resume, :destroy, :console]
  before_action :start_console_tunnel, only: [:console]

  def index
    @vms = Vm.includes(:host).all
    @vms = @vms.where(status: params[:status]) if params[:status].present?
    @vms = @vms.where(host_id: params[:host_id]) if params[:host_id].present?
  end

  def show
    @host = @vm.host
  end

  def start
    service = LibvirtService.new(@vm.host)
    service.start_vm(@vm.name)
    redirect_to vm_path(@vm), notice: "VM start command sent"
  rescue => e
    redirect_to vm_path(@vm), alert: "Failed to start VM: #{e.message}"
  end

  def shutdown
    service = LibvirtService.new(@vm.host)
    service.shutdown_vm(@vm.name)
    redirect_to vm_path(@vm), notice: "VM shutdown command sent"
  rescue => e
    redirect_to vm_path(@vm), alert: "Failed to shutdown VM: #{e.message}"
  end

  def reboot
    service = LibvirtService.new(@vm.host)
    service.reboot_vm(@vm.name)
    redirect_to vm_path(@vm), notice: "VM reboot command sent"
  rescue => e
    redirect_to vm_path(@vm), alert: "Failed to reboot VM: #{e.message}"
  end

  def pause
    service = LibvirtService.new(@vm.host)
    service.pause_vm(@vm.name)
    redirect_to vm_path(@vm), notice: "VM paused"
  rescue => e
    redirect_to vm_path(@vm), alert: "Failed to pause VM: #{e.message}"
  end

  def resume
    service = LibvirtService.new(@vm.host)
    service.resume_vm(@vm.name)
    redirect_to vm_path(@vm), notice: "VM resumed"
  rescue => e
    redirect_to vm_path(@vm), alert: "Failed to resume VM: #{e.message}"
  end

  def destroy
    service = LibvirtService.new(@vm.host)
    service.destroy_vm(@vm.name)
    redirect_to vm_path(@vm), notice: "VM destroyed (forced poweroff)"
  rescue => e
    redirect_to vm_path(@vm), alert: "Failed to destroy VM: #{e.message}"
  end

  def console
    @host = @vm.host
    service = LibvirtService.new(@vm.host)
    @console_info = service.get_console_info(@vm.name)

    if @console_info
      # Parse VNC/SPICE display to get port
      # Format: vnc://127.0.0.1:1 or spice://127.0.0.1:5900
      # VNC display :1 = port 5901, :0 = 5900, etc.
      url = @console_info[:url]
      if url =~ /:(\d+)(?::\d+)?$/
        port_or_display = $1.to_i
        # If port < 100, it's a display number, convert to port (5900 + display)
        @vnc_port = port_or_display < 100 ? 5900 + port_or_display : port_or_display
        @ws_port = 6080 + (@host.id * 100) + (@vnc_port % 100)
      end
    end
  rescue => e
    Rails.logger.error("Console error: #{e.message}")
  end

  private

  def set_vm
    @vm = Vm.includes(:host).find(params[:id])
  end

  def start_console_tunnel
    return unless @console_info && @vnc_port

    console_service = ConsoleService.new(@vm.host)
    begin
      console_service.get_websocket_url(@vnc_port)
    rescue ConsoleService::TunnelError => e
      redirect_to vm_path(@vm), alert: "Failed to start console tunnel: #{e.message}"
    end
  end
end
