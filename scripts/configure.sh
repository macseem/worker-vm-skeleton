#!/bin/bash
set -e

# Configure users and system

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Create users
create_users() {
    log_info "Creating users..."
    
    # Create macseem user if doesn't exist
    if ! id "$MACSEEM_USERNAME" &>/dev/null; then
        useradd -m -s /bin/zsh "$MACSEEM_USERNAME"
        log_info "Created user: $MACSEEM_USERNAME (shell: zsh)"
    else
        log_warn "User $MACSEEM_USERNAME already exists"
    fi
    
    # Create worker user if doesn't exist
    if ! id "$WORKER_USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$WORKER_USERNAME"
        log_info "Created user: $WORKER_USERNAME (shell: bash)"
    else
        log_warn "User $WORKER_USERNAME already exists"
    fi
}

# Setup SSH keys and GitHub integration
setup_ssh_keys() {
    log_info "Setting up SSH keys..."
    
    # Setup for macseem
    MACSEEM_HOME=$(eval echo ~$MACSEEM_USERNAME)
    mkdir -p "$MACSEEM_HOME/.ssh"
    chmod 700 "$MACSEEM_HOME/.ssh"
    
    # Add user's public key to macseem authorized_keys
    echo "$USER_PUBLIC_KEY" >> "$MACSEEM_HOME/.ssh/authorized_keys"
    chmod 600 "$MACSEEM_HOME/.ssh/authorized_keys"
    chown -R "$MACSEEM_USERNAME:$MACSEEM_USERNAME" "$MACSEEM_HOME/.ssh"
    log_info "Added your SSH key to $MACSEEM_USERNAME authorized_keys"
    
    # Generate ed25519 key for macseem
    MACSEEM_KEYFILE="$MACSEEM_HOME/.ssh/id_ed25519"
    if [[ ! -f "$MACSEEM_KEYFILE" ]]; then
        ssh-keygen -t ed25519 -C "$MACSEEM_USERNAME@$DOMAIN" -f "$MACSEEM_KEYFILE" -N ""
        chown "$MACSEEM_USERNAME:$MACSEEM_USERNAME" "$MACSEEM_KEYFILE"*
        log_info "Generated SSH key for $MACSEEM_USERNAME"
    fi
    
    # Add macseem's public key to GitHub
    MACSEEM_PUBKEY=$(cat "${MACSEEM_KEYFILE}.pub")
    add_key_to_github "$MACSEEM_PUBKEY" "$MACSEEM_USERNAME"
    
    # Setup for worker
    WORKER_HOME=$(eval echo ~$WORKER_USERNAME)
    mkdir -p "$WORKER_HOME/.ssh"
    chmod 700 "$WORKER_HOME/.ssh"
    
    # Add user's public key to worker authorized_keys (optional access)
    echo "$USER_PUBLIC_KEY" >> "$WORKER_HOME/.ssh/authorized_keys"
    chmod 600 "$WORKER_HOME/.ssh/authorized_keys"
    chown -R "$WORKER_USERNAME:$WORKER_USERNAME" "$WORKER_HOME/.ssh"
    
    # Generate ed25519 key for worker
    WORKER_KEYFILE="$WORKER_HOME/.ssh/id_ed25519"
    if [[ ! -f "$WORKER_KEYFILE" ]]; then
        ssh-keygen -t ed25519 -C "$WORKER_USERNAME@$DOMAIN" -f "$WORKER_KEYFILE" -N ""
        chown "$WORKER_USERNAME:$WORKER_USERNAME" "$WORKER_KEYFILE"*
        log_info "Generated SSH key for $WORKER_USERNAME"
    fi
    
    # Add worker's public key to GitHub
    WORKER_PUBKEY=$(cat "${WORKER_KEYFILE}.pub")
    add_key_to_github "$WORKER_PUBKEY" "$WORKER_USERNAME"
    
    # Display private keys (WARNING: shown once!)
    echo ""
    log_warn "=========================================="
    log_warn "PRIVATE KEYS - SAVE THESE SECURELY NOW!"
    log_warn "=========================================="
    echo ""
    log_warn "${MACSEEM_USERNAME} private key:"
    cat "$MACSEEM_KEYFILE"
    echo ""
    log_warn "${WORKER_USERNAME} private key:"
    cat "$WORKER_KEYFILE"
    echo ""
    log_warn "=========================================="
    log_warn "Copy these keys to secure storage NOW!"
    log_warn "=========================================="
    echo ""
    
    # Clear keys from memory
    unset MACSEEM_PUBKEY
    unset WORKER_PUBKEY
}

# Add SSH key to GitHub
add_key_to_github() {
    local pubkey=$1
    local username=$2
    
    log_info "Adding SSH key to GitHub for $username..."
    
    curl -X POST \
        -H "Authorization: token $GITHUB_API_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user/keys \
        -d "{\"title\":\"$username@$DOMAIN\",\"key\":\"$pubkey\"}" \
        -s -o /dev/null -w "%{http_code}"
    
    if [[ $? -eq 0 ]]; then
        log_info "Successfully added SSH key to GitHub for $username"
    else
        log_warn "Failed to add SSH key to GitHub for $username"
        log_warn "You may need to add it manually"
    fi
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    log_info "Docker installed successfully"
}

# Configure Docker permissions
configure_docker() {
    log_info "Configuring Docker permissions..."
    
    # Add macseem to docker group
    usermod -aG docker "$MACSEEM_USERNAME"
    log_info "Added $MACSEEM_USERNAME to docker group"
    
    # Create docker-apps directories
    MACSEEM_HOME=$(eval echo ~$MACSEEM_USERNAME)
    mkdir -p "$MACSEEM_HOME/docker-apps"
    chown "$MACSEEM_USERNAME:$MACSEEM_USERNAME" "$MACSEEM_HOME/docker-apps"
    log_info "Created docker-apps directory for $MACSEEM_USERNAME"
    
    # Create worker docker-apps directory
    WORKER_HOME=$(eval echo ~$WORKER_USERNAME)
    mkdir -p "$WORKER_HOME/docker-apps"
    chown "$WORKER_USERNAME:$WORKER_USERNAME" "$WORKER_HOME/docker-apps"
    log_info "Created docker-apps directory for $WORKER_USERNAME"
}

# Install additional tools
install_tools() {
    log_info "Installing additional tools..."
    
    # Install zsh for macseem
    apt-get install -y zsh
    
    # Install curl, jq, git
    apt-get install -y curl jq git
    
    log_info "Additional tools installed"
}

# Main configuration
main() {
    log_info "Starting system configuration..."
    
    create_users
    setup_ssh_keys
    install_docker
    configure_docker
    install_tools
    
    log_info "Configuration complete!"
}

main
