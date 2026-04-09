# Service to manage VNC console access via SSH tunneling and websockify
class ConsoleService
  class TunnelError < StandardError; end

  def initialize(host)
    @host = host
    @tunnels_dir = Rails.root.join('tmp', 'console_tunnels')
    @tunnels_dir.mkpath unless @tunnels_dir.exist?
  end

  # Get WebSocket URL for noVNC connection
  # Creates SSH tunnel and websockify process if needed
  def get_websocket_url(vnc_port)
    @vnc_port = vnc_port
    @ws_port = calculate_local_port        # Port for browser WebSocket connection
    @tunnel_port = calculate_tunnel_port   # Port for SSH tunnel (internal)

    # Check if tunnel already exists
    if tunnel_running?
      return "ws://localhost:#{@ws_port}"
    end

    # Start new tunnel
    start_tunnel
    "ws://localhost:#{@ws_port}"
  end

  # Stop a specific tunnel
  def stop_tunnel
    pid_file = tunnel_pid_file
    return unless pid_file.exist?

    pid = pid_file.read.strip.to_i
    Process.kill('TERM', pid) if process_running?(pid)
    pid_file.unlink
  end

  # Clean up all tunnels
  def cleanup_all
    @tunnels_dir.glob('*.pid').each do |pid_file|
      pid = pid_file.read.strip.to_i
      Process.kill('TERM', pid) if process_running?(pid)
      pid_file.unlink
    end
  end

  private

  def calculate_local_port
    # WebSocket port for websockify (what browser connects to)
    6080 + (@host.id * 100) + (@vnc_port % 100)
  end

  def calculate_tunnel_port
    # Local port for SSH tunnel (internal, websockify connects here)
    16080 + (@host.id * 100) + (@vnc_port % 100)
  end

  def tunnel_pid_file
    @tunnels_dir.join("host_#{@host.id}_ws_#{@ws_port}.pid")
  end

  def tunnel_log_file
    @tunnels_dir.join("host_#{@host.id}_ws_#{@ws_port}.log")
  end

  def tunnel_running?
    pid_file = tunnel_pid_file
    return false unless pid_file.exist?

    pid = pid_file.read.strip.to_i
    process_running?(pid)
  end

  def process_running?(pid)
    Process.getpgid(pid)
    true
  rescue Errno::ESRCH
    false
  end

  def start_tunnel
    ssh_key = @host.ssh_key_path
    ssh_user = @host.ssh_user
    ssh_host = @host.hostname

    # SSH command with -f to fork to background properly
    ssh_cmd = [
      'ssh', '-f', '-N',
      '-i', ssh_key,
      '-o', 'StrictHostKeyChecking=no',
      '-o', 'UserKnownHostsFile=/dev/null',
      '-o', 'ServerAliveInterval=30',
      '-o', 'ServerAliveCountMax=3',
      '-L', "#{@tunnel_port}:localhost:#{@vnc_port}",
      "#{ssh_user}@#{ssh_host}"
    ].join(' ')

    # Run SSH in background (the -f flag makes it fork itself)
    system(ssh_cmd, out: '/dev/null', err: '/dev/null')
    sleep 1

    # Find the SSH process by looking at the command line
    ssh_pid = find_ssh_tunnel_pid

    unless ssh_pid && process_running?(ssh_pid)
      raise TunnelError, "Failed to establish SSH tunnel"
    end

    # Start websockify
    start_websockify(ssh_pid)
  end

  def find_ssh_tunnel_pid
    # Find SSH process by looking for our tunnel port in command line
    result = `ps aux | grep "ssh.*#{@tunnel_port}" | grep -v grep | awk '{print $2}'`.strip
    result.split("\n").first&.to_i
  end

  def start_websockify(ssh_pid)
    # websockify connects local WebSocket to SSH tunnel
    websockify_cmd = [
      'websockify',
      '-D',  # Daemonize
      @ws_port.to_s,
      "localhost:#{@tunnel_port}"
    ].join(' ')

    # Run websockify in background
    system(websockify_cmd, out: '/dev/null', err: '/dev/null')
    sleep 1

    # Find websockify PID
    ws_pid = find_websockify_pid

    unless ws_pid && process_running?(ws_pid)
      stop_tunnel
      raise TunnelError, "Failed to start websockify"
    end

    # Store PIDs
    tunnel_pid_file.write("#{ssh_pid}\n#{ws_pid}")

    Rails.logger.info "Started console tunnel: SSH(#{ssh_pid}) + websockify(#{ws_pid}) -> localhost:#{@ws_port} (tunnel: #{@tunnel_port})"
  end

  def find_websockify_pid
    result = `ps aux | grep "websockify.*#{@ws_port}" | grep -v grep | awk '{print $2}'`.strip
    result.split("\n").first&.to_i
  end
end
