class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_current_user

  helper_method :current_user, :user_signed_in?

  private

  def authenticate_user!
    redirect_to login_path unless session[:user_id]
  end

  def set_current_user
    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_user
    @current_user
  end

  def user_signed_in?
    current_user.present?
  end

  def require_admin!
    redirect_to root_path, alert: "Admin access required" unless current_user&.admin?
  end
end
