class Vm < ApplicationRecord
  belongs_to :host
  has_many :alerts, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :name, presence: true

  enum :status, { stopped: "stopped", running: "running", paused: "paused", crashed: "crashed" }, validate: true

  default_scope { order(:name) }

  def cpu_usage_percent
    # Will be populated by sync job
    0
  end

  def memory_usage_percent
    return 0 if memory_mb.zero? || host.memory_total.zero?
    (memory_mb.to_f / host.memory_total * 100).round(2)
  end
end
