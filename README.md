# VirtVision - KVM/Virtual Machine Monitor

A Rails-based web application for managing multiple KVM/libvirt servers with VNC console access.

## Features

- **Multi-Host Management** - Manage multiple KVM hosts via SSH key-based authentication
- **VM Discovery & Monitoring** - Automatic discovery and status monitoring of VMs
- **VM Power Controls** - Start, stop, reboot, pause, resume, and destroy VMs
- **Web-Based VNC Console** - Browser-based console access via noVNC with SSH tunneling
- **Dashboard** - Overview of hosts and VMs with status indicators
- **Alert System** - Email and webhook notifications for VM events
- **User Authentication** - Built-in user management
- **Automatic Sync** - Background polling detects VM state changes (every 2 minutes)

## Requirements

### Server Requirements
- Ruby 3.4.6
- Rails 8.0.4+
- SQLite3 (development) or PostgreSQL (production)
- Node.js and npm (for noVNC)
- Python 3 with pip (for websockify)

### Host Requirements
- KVM/libvirt enabled Linux server
- SSH key-based authentication
- `virsh` command available
- VNC or SPICE graphics configured for VMs

## Installation

### Method 1: Development (Quick Start)

```bash
# Clone the repository
cd virt-vision

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
npm install

# Install websockify for console access
pip3 install --break-system-packages websockify

# Setup database
bin/rails db:setup

# Start the application
bin/dev

# Or start components separately:
bin/rails server          # Rails app
bin/rails solid_queue:start  # Background jobs
```

Visit http://localhost:3000 and login with:
- Email: `admin@localhost`
- Password: `admin123`

### Method 2: Production with Phusion Passenger

```bash
# Install Passenger and nginx
gem install passenger
sudo apt-get install -y nginx libnginx-mod-http-passenger

# Configure nginx
sudo passenger-config install-nginx-module

# Create nginx config
sudo nano /etc/nginx/sites-available/virt-vision
```

**nginx configuration:**
```nginx
server {
    listen 80;
    server_name your-domain.com;
    root /path/to/virt-vision/public;

    passenger_enabled on;
    passenger_app_env production;
    passenger_ruby /usr/bin/ruby3.4;

    # For console WebSocket connections
    location /novnc {
        proxy_pass http://localhost:6080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

**Production setup:**
```bash
# Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# Setup production database
RAILS_ENV=production bin/rails db:setup

# Create admin user
RAILS_ENV=production bin/rails runner "User.create!(email: 'admin@yourdomain.com', password: 'secure_password', password_confirmation: 'secure_password', name: 'Admin')"

# Restart nginx
sudo systemctl restart nginx

# Start SolidQueue
RAILS_ENV=production bin/rails solid_queue:start
```

### Method 3: Docker Deployment

**Dockerfile:**
```dockerfile
FROM ruby:3.4.6-slim

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential libsqlite3-dev nodejs npm python3-pip \
    openssh-client && \
    pip3 install --break-system-packages websockify

# Set working directory
WORKDIR /app

# Copy application
COPY . .

# Install gems
RUN bundle install

# Install npm packages
RUN npm install

# Precompile assets
RUN RAILS_ENV=production bin/rails assets:precompile

# Expose port
EXPOSE 3000

# Start application
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - ./db:/app/db
      - ./storage:/app/storage
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=your_secret_key_here
    restart: unless-stopped

  solid_queue:
    build: .
    command: bin/rails solid_queue:start
    volumes:
      - ./db:/app/db
      - ./storage:/app/storage
    environment:
      - RAILS_ENV=production
    depends_on:
      - app
    restart: unless-stopped
```

**Build and run:**
```bash
docker-compose up -d --build
```

### Method 4: Systemd Service

**Create service file:**
```bash
sudo nano /etc/systemd/system/virt-vision.service
```

**Service configuration:**
```ini
[Unit]
Description=VirtVision Rails Application
After=network.target

[Service]
Type=notify
WorkingDirectory=/path/to/virt-vision
Environment=RAILS_ENV=production
Environment=SECRET_KEY_BASE=your_secret_key_here
ExecStart=/home/chollien/.rbenv/versions/3.4.6/bin/rails server -e production -b 127.0.0.1 -p 3000
Restart=always
User=chollien
Group=chollien

[Install]
WantedBy=multi-user.target
```

**SolidQueue service:**
```bash
sudo nano /etc/systemd/system/virt-vision-queue.service
```

```ini
[Unit]
Description=VirtVision SolidQueue
After=network.target virt-vision.service

[Service]
Type=notify
WorkingDirectory=/path/to/virt-vision
Environment=RAILS_ENV=production
ExecStart=/home/chollien/.rbenv/versions/3.4.6/bin/rails solid_queue:start
Restart=always
User=chollien
Group=chollien

[Install]
WantedBy=multi-user.target
```

**Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable virt-vision virt-vision-queue
sudo systemctl start virt-vision
sudo systemctl status virt-vision
```

## Configuration

### SSH Key Setup

Generate SSH key for host connections:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

Copy public key to each KVM host:
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@kvm-host
```

Test connection:
```bash
ssh -i ~/.ssh/id_ed25519 user@kvm-host "sudo virsh list"
```

### Host Configuration

1. Login to VirtVision
2. Go to Hosts → New Host
3. Enter:
   - **Name**: Friendly name (e.g., "Production KVM")
   - **Hostname**: IP address or FQDN
   - **SSH User**: SSH username
   - **SSH Key Path**: Full path to private key (e.g., `/home/user/.ssh/id_ed25519`)
4. Click "Test Connection" to verify
5. Click "Save"
6. Click "Sync" to discover VMs

### VNC Console Setup

The console uses SSH tunneling + websockify to provide browser-based VNC access. No additional configuration needed on remote hosts.

**Requirements:**
- websockify installed on the Rails server
- VNC graphics configured on VMs

**For SPICE VMs:**
The console page will show instructions to either:
1. Use `remote-viewer spice://host:port` with virt-viewer
2. Reconfigure VM for VNC: `virsh edit vmname`

Change graphics from:
```xml
<graphics type='spice' ...>
```
To:
```xml
<graphics type='vnc' port='-1' autoport='yes'/>
```

## Background Jobs

SolidQueue handles:
- **HostSyncJob** - Syncs host status and VMs every 2 minutes
- **AlertCheckJob** - Checks alert conditions every 2 minutes

Start the queue processor:
```bash
bin/rails solid_queue:start
```

For production with systemd, use the service files above.

## Troubleshooting

### Console not working

1. Check websockify is installed:
```bash
which websockify
```

2. Check SSH tunnel connectivity:
```bash
ssh -i /path/to/key user@host "sudo virsh domdisplay vmname"
```

3. Check ports are listening:
```bash
netstat -tlnp | grep -E "(6080|16080)"
```

4. Check browser console for errors (F12)

### VMs not discovered

1. Verify SSH connection works
2. Check virsh commands work remotely:
```bash
ssh -i key user@host "sudo virsh list --all"
```

3. Check host status in the app (should be "online")

### Sync not running

1. Check SolidQueue is running:
```bash
ps aux | grep solid_queue
```

2. Check recurring jobs:
```bash
bin/rails runner "puts SolidQueue::RecurringTask.all.map(&:name)"
```

3. Check logs:
```bash
tail -f log/development.log | grep -i sync
```

## Architecture

```
┌─────────────┐      SSH       ┌──────────────┐
│   Browser   │ ──────────────>│  KVM Host    │
│   (noVNC)   │                │  (VNC :5901) │
└──────┬──────┘                └──────────────┘
       │ WebSocket
       │ ws://localhost:6281
┌──────▼──────┐      SSH       ┌──────────────┐
│ Websockify  │ ──────────────>│  KVM Host    │
│  (:6281)    │  tunnel :16281 │  (VNC :5901) │
└─────────────┘                └──────────────┘
       │
┌──────▼──────┐
│ Rails App   │
│  (:3000)    │
└─────────────┘
```

## License

MIT License - See LICENSE file for details.
