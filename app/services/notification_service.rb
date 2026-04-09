# Service for sending notifications via email and webhook
class NotificationService
  class << self
    def send_alert(alert, resource)
      Rails.logger.info("Sending alert: #{alert.name} for #{resource.class} ##{resource.id}")

      case alert.notification_channel
      when "email"
        send_email(alert, resource)
      when "webhook"
        send_webhook(alert, resource)
      when "both"
        send_email(alert, resource)
        send_webhook(alert, resource)
      end
    end

    def send_email(alert, resource)
      # Get admin users to notify
      admins = User.where(role: "admin")
      return if admins.empty?

      AdminMailer.alert_notification(alert, resource, admins).deliver_later
    end

    def send_webhook(alert, resource)
      webhook_url = Setting.find_by(key: "webhook_url")&.value
      return unless webhook_url

      payload = {
        alert_name: alert.name,
        condition_type: alert.condition_type,
        resource_type: resource.class.name,
        resource_name: resource.name,
        resource_status: resource.status,
        timestamp: Time.current.iso8601
      }

      HTTParty.post(webhook_url, {
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 10
      })
    rescue => e
      Rails.logger.error("Failed to send webhook: #{e.message}")
    end
  end
end
