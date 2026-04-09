class AlertsController < ApplicationController
  before_action :require_admin!
  before_action :set_alert, only: [:edit, :update, :destroy, :toggle]

  def index
    @alerts = Alert.includes(:host, :vm).all
  end

  def new
    @alert = Alert.new
    @hosts = Host.all
    @vms = Vm.all
  end

  def create
    @alert = Alert.new(alert_params)
    if @alert.save
      redirect_to alerts_path, notice: "Alert created successfully"
    else
      @hosts = Host.all
      @vms = Vm.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @hosts = Host.all
    @vms = Vm.all
  end

  def update
    if @alert.update(alert_params)
      redirect_to alerts_path, notice: "Alert updated successfully"
    else
      @hosts = Host.all
      @vms = Vm.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @alert.destroy
    redirect_to alerts_path, notice: "Alert deleted"
  end

  def toggle
    @alert.update!(enabled: !@alert.enabled)
    redirect_to alerts_path, notice: "Alert #{@alert.enabled ? 'enabled' : 'disabled'}"
  end

  private

  def set_alert
    @alert = Alert.find(params[:id])
  end

  def alert_params
    params.require(:alert).permit(
      :name, :condition_type, :threshold, :enabled,
      :notification_channel, :host_id, :vm_id
    )
  end
end
