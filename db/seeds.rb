# VirtVision default seed data

# Create default admin user
admin = User.find_or_initialize_by(email: "admin@localhost")
admin.assign_attributes(
  name: "Administrator",
  password: "admin123",
  role: "admin"
)
admin.save!

puts "Default admin user created:"
puts "  Email: admin@localhost"
puts "  Password: admin123"

# Create default settings
Setting.find_or_create_by(key: "webhook_url") do |s|
  s.value = ""
end

Setting.find_or_create_by(key: "smtp_enabled") do |s|
  s.value = "false"
end

puts "Default settings created"
