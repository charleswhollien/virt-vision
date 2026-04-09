class AdminMailer < ApplicationMailer
  default from: "virt-vision@localhost"

  def alert_notification(alert, resource, admins)
    @alert = alert
    @resource = resource
    @admins = admins

    mail(
      to: admins.pluck(:email),
      subject: "[VirtVision Alert] #{alert.name} - #{resource.name}"
    )
  end
end
