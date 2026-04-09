class Host < ApplicationRecord
  has_many :vms, dependent: :destroy
  has_many :alerts, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :hostname, presence: true
  validates :ssh_user, presence: true

  enum :status, { offline: "offline", online: "online", error: "error" }, validate: true, default: "offline"

  default_scope { order(:name) }

  def connection_string
    "qemu+ssh://#{ssh_user}@#{hostname}/system"
  end

  def connected?
    status == "online" && last_polled_at.present? && last_polled_at > 5.minutes.ago
  end
end
