# worker-vm-skeleton

A reproducible, opinionated template for setting up a secure Docker hosting environment on a single VM.

## Overview

This template sets up:
- **macseem** user: Personal development access (zsh, SSH, docker group)
- **worker** user: Container execution identity (bash, no SSH)
- **nginx-proxy-manager**: Reverse proxy with Cloudflare SSL
- **Portainer**: Web-based Docker management
- **Cloudflare DNS**: Automatic subdomain management

## Quick Start

### Prerequisites

- Ubuntu 20.04+ VM
- Root or sudo access
- Cloudflare API token (DNS edit permissions)
- GitHub API token (write:public_key scope)
- Your SSH public key

### Installation

1. **Clone the repository on your laptop:**

```bash
git clone https://github.com/macseem/worker-vm-skeleton.git
cd worker-vm-skeleton
```

2. **Set up DNS with Terraform (from laptop):**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

3. **Copy to VM and run setup (on VM as root):**

```bash
# On your laptop
scp -r worker-vm-skeleton root@your-vm-ip:/tmp/

# SSH to VM
ssh root@your-vm-ip
cd /tmp/worker-vm-skeleton/scripts
./setup.sh
```

4. **Follow the prompts:**
   - GitHub API token
   - Your SSH public key
   - Usernames (default: macseem, worker)
   - Domain (default: dudkin-garage.com)

5. **Save the displayed private keys securely!**

### Post-Setup Configuration

1. **Access nginx-proxy-manager admin:**
   - URL: `http://your-vm-ip:81`
   - Default: `admin@example.com` / `changeme`
   - Change password immediately!

2. **Add Cloudflare Origin Certificate:**
   - Go to SSL Certificates → Add SSL Certificate → Custom
   - Upload your Cloudflare origin certificate and key

3. **Configure Proxy Hosts:**
   - Domain: `portainer.dudkin-garage.com`
   - Forward Hostname/IP: `portainer`
   - Forward Port: `9000`
   - Enable Block Common Exploits

4. **Access Portainer:**
   - URL: `https://portainer.dudkin-garage.com`
   - Create admin user on first login

## Usage

### As macseem (your personal user)

```bash
# SSH to VM
ssh macseem@your-vm-ip

# Create new app
cd ~/docker-apps
mkdir myapp
cd myapp
nano docker-compose.yml

# Deploy
docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Helper Scripts

Available in `~/docker-apps/`:

- `./start.sh` - Start all services
- `./stop.sh` - Stop all services  
- `./logs.sh <name>` - View service logs

## Architecture

```
Internet
    │
    ▼ HTTPS (443)
Cloudflare Proxy
    │
    ▼
nginx-proxy-manager
    │
    ▼ localhost:9000
Portainer CE
    │
    ▼ Docker Engine
Your Containers
```

## File Structure

```
worker-vm-skeleton/
├── features/prd.md              # Product Requirements Document
├── terraform/                   # DNS management
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── scripts/                     # Setup scripts
│   ├── setup.sh                # Main entry point
│   ├── configure.sh            # Users, Docker install
│   └── install.sh              # Infrastructure services
├── docker-apps/                 # Docker compose files
│   ├── npm/
│   │   └── docker-compose.yml
│   └── portainer/
│       └── docker-compose.yml
├── config/                      # SSL certificates
│   ├── cloudflare-origin.pem
│   └── cloudflare-origin.key
├── README.md
└── .gitignore
```

## Security

- SSH key-based authentication only
- No password authentication
- macseem: Full Docker access via docker group
- worker: Container execution identity
- Cloudflare Origin certificates for TLS
- All infrastructure services isolated to localhost

## Maintenance

### Backup

```bash
# Backup Docker volumes
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine tar czf /backup/portainer-backup.tar.gz /data
```

### Update

```bash
# Update images
cd ~/docker-apps/<service>
docker compose pull
docker compose up -d
```

### Logs

```bash
# Infrastructure logs
docker logs -f npm
docker logs -f portainer
```

## Troubleshooting

### Portainer not accessible

1. Check if portainer container is running: `docker ps`
2. Check logs: `docker logs portainer`
3. Verify NPM proxy host configuration

### SSH not working

1. Verify your public key was added: `cat ~/.ssh/authorized_keys`
2. Check SSH service: `systemctl status ssh`
3. Check firewall: `ufw status`

### DNS not resolving

1. Check Cloudflare records: `terraform show`
2. Verify VM IP in terraform.tfvars
3. Check Cloudflare proxy status

## Contributing

This is a personal template. Feel free to fork and customize for your needs.

## License

MIT
