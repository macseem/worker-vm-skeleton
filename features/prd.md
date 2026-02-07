# Product Requirements Document: worker-vm-skeleton

## 1. Overview

**worker-vm-skeleton** is a reproducible, opinionated template for setting up a secure Docker hosting environment on a single VM. It separates personal user access (macseem) from container execution (worker), manages DNS via Cloudflare, and provides web-based container management via nginx-proxy-manager and Portainer.

## 2. Goals

- **Reproducible**: Clone repo → run script → working environment
- **Secure**: No password auth, SSH keys only, separate users
- **Portable**: Works on any Ubuntu VM
- **Low-maintenance**: Infrastructure services auto-start, minimal运维
- **Developer-friendly**: macseem uses familiar tools (zsh, docker compose)

## 3. Non-Goals

- Multi-VM orchestration (single VM only)
- Enterprise features (RBAC, SSO, audit logs)
- Cloud-specific provisioning (cloud-init, Terraform VM creation)
- Ansible/Terraform for OS configuration

## 4. Users & Roles

| User | Shell | SSH Access | Docker Access | Purpose |
|------|-------|------------|---------------|---------|
| macseem | zsh | Yes (from laptop) | Full (docker group) | Personal developer access |
| worker | bash | No | N/A | Container execution identity |

## 5. Architecture

```
Internet
    │
    ▼ HTTPS (port 443)
┌─────────────────────────────────────────────┐
│  Cloudflare Proxy                          │
│  - DNS: *.dudkin-garage.com → VM          │
│  - SSL: Origin certificate                 │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  nginx-proxy-manager (docker, worker)      │
│  - Ports: 80, 443, 81 (admin)             │
│  - Routes: portainer → localhost:9000      │
└─────────────────────────────────────────────┘
    │
    ▼ localhost:9000
┌─────────────────────────────────────────────┐
│  Portainer CE (docker, worker)             │
│  - Web UI for Docker management            │
└─────────────────────────────────────────────┘
    │
    ▼ Docker Engine
┌─────────────────────────────────────────────┐
│  User Containers (run as worker)          │
└─────────────────────────────────────────────┘
```

## 6. Features

### 6.1 Automated VM Configuration

**As a** developer **I want** to run a single script **so that** the VM is configured without manual steps.

**Requirements:**
- Create specified users (macseem, worker) with home directories
- Add macseem to docker group
- Install Docker Engine and docker-compose plugin
- Generate SSH key pairs for both users
- Add user's public SSH key to authorized_keys

### 6.2 GitHub SSH Key Integration

**As a** developer **I want** SSH keys to be automatically added to GitHub **so that** git operations work without manual key management.

**Requirements:**
- Generate ed25519 SSH key pairs for macseem and worker
- Prompt for GitHub API token during setup
- Add public keys to GitHub via API (write:public_key scope)
- Display private keys for local saving

### 6.3 Cloudflare DNS Management

**As a** developer **I want** DNS records to be created automatically **so that** subdomains resolve without manual DNS configuration.

**Requirements:**
- Terraform manages Cloudflare DNS records
- Create A records for subdomains
- Support wildcard records (*.dudkin-garage.com)
- Output created records after apply

### 6.4 Reverse Proxy Setup

**As a** developer **I want** nginx-proxy-manager to route subdomains **so that** multiple services are accessible via HTTPS.

**Requirements:**
- Deploy nginx-proxy-manager as Docker container (worker user)
- Configure SSL using Cloudflare Origin certificates
- Set up proxy host: portainer.dudkin-garage.com → localhost:9000
- Admin UI accessible on port 81

### 6.5 Container Management UI

**As a** developer **I want** Portainer to manage containers via web UI **so that** I can monitor, restart, and configure containers visually.

**Requirements:**
- Deploy Portainer CE as Docker container (worker user)
- Bind to localhost:9000 only (NPM handles external access)
- HTTPS access via portainer subdomain
- Initial admin user setup on first access

### 6.6 Developer Workflow

**As a** developer **I want** to manage my containers from my user account **so that** my workflow remains familiar and comfortable.

**Requirements:**
- macseem user has docker group membership
- Project files stored in ~/docker-apps/
- Standard docker-compose workflow
- Containers run as worker automatically

## 7. User Stories

| ID | Title | Description | Priority |
|----|-------|-------------|----------|
| US-1 | Initial Setup | Developer clones repo, runs setup.sh, VM is ready | Must |
| US-2 | SSH Access | Developer SSHs as macseem using their key | Must |
| US-3 | Git Access | Developer clones repos via SSH without manual key setup | Must |
| US-4 | DNS Resolution | portainer.dudkin-garage.com resolves to VM | Must |
| US-5 | Container Management | Developer opens Portainer UI and sees running containers | Must |
| US-6 | Deploy App | Developer creates docker-compose.yml and deploys app | Should |
| US-7 | Add Service | Developer adds new subdomain for another service | Should |
| US-8 | Infrastructure Recovery | VM restarts, infrastructure services auto-start | Should |

## 8. Input Requirements

| Variable | Description | Source |
|----------|-------------|--------|
| GITHUB_API_TOKEN | GitHub token with write:public_key scope | User during setup |
| CLOUDFLARE_API_TOKEN | Cloudflare API token with DNS edit | terraform.tfvars |
| CLOUDFLARE_ZONE_ID | DNS zone ID for dudkin-garage.com | terraform.tfvars |
| USER_PUBLIC_KEY | User's SSH public key for VM access | User during setup |
| MACSEEM_USERNAME | Username for personal user | User during setup |
| WORKER_USERNAME | Username for container user | User during setup |

## 9. Output Artifacts

| Artifact | Description |
|----------|-------------|
| SSH private keys | Displayed for user to save (shown once) |
| Portainer URL | https://portainer.dudkin-garage.com |
| NPM Admin URL | http://vm-ip:81 |
| Terraform output | DNS records created |

## 10. File Structure

```
worker-vm-skeleton/
├── features/
│   └── prd.md            # This document
│
├── terraform/
│   ├── main.tf           # Cloudflare DNS resources
│   ├── variables.tf      # Input variables
│   ├── outputs.tf        # DNS record outputs
│   └── terraform.tfvars   # Local values (gitignored)
│
├── scripts/
│   ├── setup.sh          # Main entry point
│   ├── configure.sh      # User creation, SSH, Docker
│   └── install.sh        # NPM + Portainer deployment
│
├── docker-apps/
│   ├── npm/
│   │   └── docker-compose.yml
│   └── portainer/
│       └── docker-compose.yml
│
├── config/
│   ├── cloudflare-origin.pem   # SSL certificate
│   └── cloudflare-origin.key   # SSL private key
│
├── README.md
└── .gitignore
```

## 11. Security Considerations

- SSH key-based authentication only (no passwords)
- Separate users for access vs. execution
- GitHub API token input during runtime (not stored)
- Cloudflare Origin certificates for TLS
- NPM admin UI on local port only

## 12. Constraints

- Single VM (no cluster)
- Ubuntu OS (20.04+)
- No ansible, no cloud-init
- Single environment (no promotion pipelines)
- Terraform for DNS only (not VM provisioning)
- Local Terraform state (migrate to cloud when needed)

## 13. Future Considerations (Out of Scope)

- Multi-node Docker Swarm
- Kubernetes integration
- CI/CD pipelines
- Backup/restore automation
- Monitoring/alerting
- Log aggregation
- Secrets management (Vault, Doppler)

## 14. Definition of Done

- [ ] All user stories pass
- [ ] Documentation complete (README.md)
- [ ] Variables documented
- [ ] Tested end-to-end on fresh VM
- [ ] Rollback procedure documented
- [ ] SSH private keys displayed and acknowledged
