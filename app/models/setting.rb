class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  scope :email_enabled, -> { where(key: "smtp_enabled", value: "true") }

  def self.[](key)
    find_by(key: key)&.value
  end

  def self.[]=(key, value)
    find_or_initialize_by(key: key).update!(value: value)
  end
end
