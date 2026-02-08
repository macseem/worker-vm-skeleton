# Ansible VM Provisioning

This directory contains Ansible playbooks to provision the worker VM with Docker, users, SSH keys, and infrastructure services (Nginx Proxy Manager and Portainer).

## Prerequisites

1. **Ansible** installed on your control machine (local machine)
   ```bash
   pip install ansible
   ```

2. **Required Ansible collections**:
   ```bash
   ansible-galaxy collection install community.crypto ansible.posix
   ```

3. **VM is running** and accessible via SSH (IP address known)

## Setup

### 1. Configure Inventory

Edit `inventory/hosts.yml` and update:
- `ansible_host`: Your VM's IP address (from Terraform output)
- `ansible_ssh_private_key_file`: Path to your SSH private key

Example:
```yaml
ansible_host: 203.0.113.10
ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### 2. Configure Secrets

Edit `group_vars/vault.yml` with your actual secrets:

```yaml
vault_github_api_token: "ghp_your_github_token_here"
vault_user_public_key: "ssh-ed25519 AAAAC3NzaC..."
vault_domain: "dudkin-garage.com"
```

### 3. Encrypt the Vault File

```bash
# Encrypt the vault file
ansible-vault encrypt group_vars/vault.yml

# You will be prompted to set a vault password
```

To edit the vault file later:
```bash
ansible-vault edit group_vars/vault.yml
```

### 4. Verify Configuration

Check that Ansible can connect to your VM:
```bash
cd ansible/
ansible -i inventory/hosts.yml worker -m ping
```

You should see a "pong" response.

## Usage

### Quick Start (Recommended)

Use the provided helper script:

```bash
# Run with interactive password prompt
./run.sh

# Use password file
./run.sh -p .vault_pass

# Run specific tags only
./run.sh -t docker,users

# Dry run (see what would change)
./run.sh -c

# Show all options
./run.sh --help
```

### Manual Ansible Commands

```bash
# With interactive password prompt
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass

# With password file (for automation)
echo "your_vault_password" > .vault_pass
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --vault-password-file .vault_pass
```

### Run Specific Tags

```bash
# Only install Docker
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass --tags docker

# Only set up users and SSH keys
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass --tags users

# Only deploy infrastructure services
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass --tags infrastructure
```

## What Gets Deployed

### Users
- **macseem**: Personal user with zsh shell, docker access
- **worker**: Service user with bash shell, docker access

Both users get:
- Your SSH public key in `authorized_keys`
- Fresh ed25519 SSH keypairs (private keys fetched to `output/`)
- Keys uploaded to GitHub (if token provided)

### Docker
- Docker CE installed
- docker-compose-plugin installed
- Both users added to docker group
- Docker service enabled and running

### Infrastructure Services
- **Nginx Proxy Manager** (http://VM_IP:81)
  - Default credentials: admin@example.com / changeme
- **Portainer** (https://portainer.YOUR_DOMAIN)
  - Requires initial admin setup on first access
- Systemd services for auto-start on boot
- Helper scripts in `~/docker-apps/`

### SSH Keys
After running, you'll find private keys in:
```
ansible/output/macseem_key
ansible/output/worker_key
```

These are your keys to access the VM as those users.

## Post-Provisioning Steps

1. **Access NPM Admin**: http://VM_IP:81
   - Login with default credentials
   - Change password
   - Configure SSL certificates (Cloudflare or Let's Encrypt)

2. **Access Portainer**: https://portainer.YOUR_DOMAIN
   - Set up admin user on first login
   - Connect to local Docker environment

3. **Configure DNS**:
   - Point `portainer.YOUR_DOMAIN` to VM IP
   - Point any app domains to VM IP

4. **Deploy Applications**:
   - Use helper scripts in `~/docker-apps/`
   - Or use Portainer to manage containers

## Troubleshooting

### Connection refused
Ensure the VM's IP is correct in `inventory/hosts.yml` and the VM is running.

### Permission denied (SSH)
Verify your SSH private key path is correct and the key has proper permissions:
```bash
chmod 600 ~/.ssh/your_key
```

### Vault decryption fails
Make sure you're providing the correct vault password with `--ask-vault-pass`

### Docker permission denied
Log out and log back in to the VM for docker group membership to take effect, or run:
```bash
newgrp docker
```

## Directory Structure

```
ansible/
├── run.sh                   # Helper script to run playbook
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml           # Target hosts
├── group_vars/
│   ├── all.yml             # Non-sensitive variables
│   └── vault.yml           # ENCRYPTED secrets
├── playbooks/
│   └── site.yml            # Main playbook
├── roles/
│   ├── common/             # Base packages
│   ├── docker/             # Docker installation
│   ├── users/              # User and SSH setup
│   └── infrastructure/     # NPM, Portainer deployment
├── output/                 # Fetched SSH keys (gitignored)
└── .gitignore             # Excludes sensitive files
```

## Security Notes

- `group_vars/vault.yml` should be encrypted before committing to git
- SSH private keys in `output/` directory are sensitive - protect them
- `.vault_pass` file should never be committed to git
- GitHub API token needs `write:public_key` scope for SSH key upload
