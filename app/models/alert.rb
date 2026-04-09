class Alert < ApplicationRecord
  belongs_to :host, optional: true
  belongs_to :vm, optional: true

  validates :name, presence: true
  validates :condition_type, presence: true

  enum :condition_type, {
    vm_stopped: "vm_stopped",
    vm_crashed: "vm_crashed",
    host_offline: "host_offline",
    high_cpu: "high_cpu",
    high_memory: "high_memory"
  }, validate: true

  enum :notification_channel, { email: "email", webhook: "webhook", both: "both" }, validate: true

  scope :enabled, -> { where(enabled: true) }
  scope :for_host, ->(host_id) { where(host_id: host_id) }
  scope :for_vm, ->(vm_id) { where(vm_id: vm_id) }
end
