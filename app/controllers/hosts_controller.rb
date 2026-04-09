class HostsController < ApplicationController
  before_action :require_admin!, except: [:index, :show]
  before_action :set_host, only: [:show, :edit, :update, :destroy, :sync, :test_connection]

  def index
    @hosts = Host.includes(:vms).all
  end

  def show
    @vms = @host.vms.order(:name)
  end

  def new
    @host = Host.new
  end

  def create
    @host = Host.new(host_params)
    if @host.save
      # Test connection after creating
      HostSyncJob.perform_later(@host.id)
      redirect_to hosts_path, notice: "Host added successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @host.update(host_params)
      HostSyncJob.perform_later(@host.id)
      redirect_to host_path(@host), notice: "Host updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @host.destroy
    redirect_to hosts_path, notice: "Host removed successfully"
  end

  def sync
    HostSyncJob.perform_later(@host.id)
    redirect_to host_path(@host), notice: "Host sync started"
  end

  def test_connection
    service = LibvirtService.new(@host)
    if service.test_connection
      redirect_to host_path(@host), notice: "Connection successful!"
    else
      redirect_to host_path(@host), alert: "Connection failed"
    end
  rescue => e
    redirect_to host_path(@host), alert: "Connection error: #{e.message}"
  end

  private

  def set_host
    @host = Host.find(params[:id])
  end

  def host_params
    params.require(:host).permit(
      :name, :hostname, :connection_uri,
      :ssh_user, :ssh_key_path, :encrypted_ssh_key
    )
  end
end
