#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Get user input
get_user_input() {
    log_info "Welcome to worker-vm-skeleton setup!"
    echo ""
    
    # Get GitHub API Token
    read -sp "Enter GitHub API Token (with write:public_key scope): " GITHUB_API_TOKEN
    echo ""
    export GITHUB_API_TOKEN
    
    # Get user's public SSH key
    read -p "Enter your SSH public key (ed25519 or rsa): " USER_PUBLIC_KEY
    if [[ -z "$USER_PUBLIC_KEY" ]]; then
        log_error "SSH public key is required"
        exit 1
    fi
    export USER_PUBLIC_KEY
    
    # Get macseem username
    read -p "Enter personal username [macseem]: " MACSEEM_USERNAME
    MACSEEM_USERNAME=${MACSEEM_USERNAME:-macseem}
    export MACSEEM_USERNAME
    
    # Get worker username
    read -p "Enter worker username [worker]: " WORKER_USERNAME
    WORKER_USERNAME=${WORKER_USERNAME:-worker}
    export WORKER_USERNAME
    
    # Get domain
    read -p "Enter your domain [dudkin-garage.com]: " DOMAIN
    DOMAIN=${DOMAIN:-dudkin-garage.com}
    export DOMAIN
    
    log_info "Configuration:"
    log_info "  Personal user: $MACSEEM_USERNAME"
    log_info "  Worker user: $WORKER_USERNAME"
    log_info "  Domain: $DOMAIN"
}

# Main setup function
main() {
    check_root
    get_user_input
    
    log_info "Starting worker-vm-skeleton setup..."
    
    # Run configuration script
    log_info "Step 1: Configuring users and system..."
    source ./configure.sh
    
    # Run installation script
    log_info "Step 2: Installing infrastructure services..."
    source ./install.sh
    
    log_info "Setup complete!"
    echo ""
    log_info "Access URLs:"
    log_info "  Portainer: https://portainer.$DOMAIN"
    log_info "  NPM Admin: http://$(hostname -I | awk '{print $1}'):81"
    echo ""
    log_warn "IMPORTANT: Save the private keys displayed above securely!"
    log_warn "They will not be shown again."
}

main "$@"
