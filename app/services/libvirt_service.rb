# Service for managing SSH connections to remote libvirt hosts
# Executes virsh commands over SSH and parses XML/JSON output
class LibvirtService
  class ConnectionError < StandardError; end
  class CommandError < StandardError; end

  def initialize(host)
    @host = host
  end

  # Test SSH connection to host
  def test_connection
    exec_ssh("echo 'connected'")
    true
  rescue ConnectionError
    false
  end

  # Get host system information
  def get_host_info
    info = exec_ssh("virsh sysinfo | grep -E '<(cpu_max|memory_total)>'")

    {
      cpu_cores: extract_xml_value(info, "cpu_max").to_i,
      memory_total_kb: extract_xml_value(info, "memory_total").to_i / 1024
    }
  rescue CommandError
    { cpu_cores: 0, memory_total_kb: 0 }
  end

  # List all VMs on the host
  def list_vms
    # Get active VMs (use sudo for system libvirt)
    active = exec_ssh("sudo virsh list --name")
    # Get inactive VMs
    inactive = exec_ssh("sudo virsh list --inactive --name")

    all_names = (active.split("\n") + inactive.split("\n")).compact.reject(&:empty?).uniq

    all_names.map do |name|
      get_vm_info(name)
    end
  end

  # Get detailed VM information
  def get_vm_info(name)
    domain_xml = exec_ssh("sudo virsh dominfo #{name.shellescape}")
    vcpu_xml = exec_ssh("sudo virsh vcpuinfo #{name.shellescape} | grep '^CPU' | wc -l")

    uuid = extract_value(domain_xml, "UUID")
    state = extract_value(domain_xml, "State")
    cpu_time = extract_value(domain_xml, "CPU time")
    memory_kb = extract_value(domain_xml, "Used memory").to_i

    # Parse disk info
    disk_xml = exec_ssh("sudo virsh domblklist #{name.shellescape} --details")
    disks = parse_disk_info(disk_xml)

    # Parse network info
    network_xml = exec_ssh("sudo virsh domiflist #{name.shellescape}")
    networks = parse_network_info(network_xml)

    {
      uuid: uuid,
      name: name,
      status: map_vm_status(state),
      cpu_count: vcpu_xml.to_i,
      memory_mb: (memory_kb / 1024.0).to_i,
      disk_info: disks.to_json,
      network_info: networks.to_json
    }
  end

  # VM power controls
  def start_vm(name)
    exec_ssh("sudo virsh start #{name.shellescape}")
  end

  def shutdown_vm(name)
    exec_ssh("sudo virsh shutdown #{name.shellescape}")
  end

  def reboot_vm(name)
    exec_ssh("sudo virsh reboot #{name.shellescape}")
  end

  def pause_vm(name)
    exec_ssh("sudo virsh suspend #{name.shellescape}")
  end

  def resume_vm(name)
    exec_ssh("sudo virsh resume #{name.shellescape}")
  end

  def destroy_vm(name)
    exec_ssh("sudo virsh destroy #{name.shellescape}")
  end

  # Get VM console URL (VNC/SPICE)
  def get_console_info(name)
    graphics_xml = exec_ssh("sudo virsh domdisplay #{name.shellescape} 2>/dev/null || echo ''")

    if graphics_xml.present?
      {
        type: graphics_xml.include?("spice") ? "spice" : "vnc",
        url: graphics_xml.strip
      }
    else
      nil
    end
  end

  # Get host CPU and memory usage stats
  def get_host_stats
    # CPU stats from /proc/stat
    cpu_stats = exec_ssh("cat /proc/stat | head -1")
    cpu_parts = cpu_stats.gsub("cpu ", "").split(/\s+/).map(&:to_i)
    cpu_total = cpu_parts.sum
    cpu_idle = cpu_parts[3] || 0
    cpu_usage = ((cpu_total - cpu_idle).to_f / cpu_total * 100).round(2)

    # Memory stats from /proc/meminfo
    mem_info = exec_ssh("cat /proc/meminfo | grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached):'")
    mem_total = extract_meminfo_value(mem_info, "MemTotal")
    mem_free = extract_meminfo_value(mem_info, "MemFree")
    mem_available = extract_meminfo_value(mem_info, "MemAvailable")
    mem_cached = extract_meminfo_value(mem_info, "Cached")

    {
      cpu_usage_percent: cpu_usage,
      memory_total_kb: mem_total,
      memory_free_kb: mem_free,
      memory_available_kb: mem_available,
      memory_cached_kb: mem_cached,
      memory_usage_percent: ((mem_total - mem_available).to_f / mem_total * 100).round(2)
    }
  rescue CommandError => e
    Rails.logger.error("Failed to get host stats: #{e.message}")
    {
      cpu_usage_percent: 0,
      memory_total_kb: 0,
      memory_free_kb: 0,
      memory_available_kb: 0,
      memory_cached_kb: 0,
      memory_usage_percent: 0
    }
  end

  private

  def exec_ssh(command)
    output = ""
    Net::SSH.start(
      @host.hostname,
      @host.ssh_user,
      ssh_options
    ) do |session|
      output = session.exec!(command)
    end
    output
  rescue Net::SSH::AuthenticationFailed,
         Net::SSH::ConnectionTimeout,
         Errno::ECONNREFUSED,
         Errno::EHOSTUNREACH => e
    raise ConnectionError, "SSH connection failed: #{e.message}"
  rescue Net::SSH::CommandTimeout => e
    raise CommandError, "SSH command timed out: #{e.message}"
  end

  def ssh_options
    options = {
      keys: [@host.ssh_key_path],
      key_data: [@host.encrypted_ssh_key].compact,
      auth_methods: ["publickey"],
      paranoid: false,
      user_known_hosts_file: "/dev/null",
      timeout: 10,
      keepalive: true,
      keepalive_interval: 5
    }

    # Disable strict host key checking for initial setup
    # In production, you'd want to manage known_hosts properly
    options[:paranoid] = false

    options
  end

  def extract_xml_value(xml, tag)
    return "" unless xml
    match = xml.match(/<#{tag}>([^<]+)<\/#{tag}>/)
    match ? match[1].strip : ""
  end

  def extract_value(output, label)
    return "" unless output
    match = output.match(/#{label}:\s*(.+)/)
    match ? match[1].strip : ""
  end

  def extract_meminfo_value(mem_info, key)
    match = mem_info.match(/^#{key}:\s+(\d+)/)
    match ? match[1].to_i : 0
  end

  def map_vm_status(state)
    case state.downcase
    when "running" then "running"
    when "shut off", "shutoff" then "stopped"
    when "paused" then "paused"
    when "crashed" then "crashed"
    else "stopped"
    end
  end

  def parse_disk_info(xml)
    disks = []
    xml.each_line do |line|
      next if line.match?(/Target|----/)
      parts = line.split(/\s+/)
      next if parts.size < 2

      disks << {
        target: parts[0],
        source: parts[1],
        type: parts[2]
      }
    end
    disks
  end

  def parse_network_info(xml)
    interfaces = []
    xml.each_line do |line|
      next if line.match?(/Interface|----/)
      parts = line.split(/\s+/)
      next if parts.size < 2

      interfaces << {
        interface: parts[0],
        type: parts[1],
        source: parts[2],
        model: parts[3],
        mac: parts[4]
      }
    end
    interfaces
  end
end
