#!/bin/bash
set -e

# Install infrastructure services (nginx-proxy-manager and portainer)

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Get WORKER_HOME
WORKER_HOME=$(eval echo ~$WORKER_USERNAME)

# Create infrastructure directory
INFRA_DIR="$WORKER_HOME/docker-apps/infrastructure"
mkdir -p "$INFRA_DIR"

# Copy docker-compose files
copy_docker_files() {
    log_info "Copying docker-compose files..."
    
    # Create npm directory
    mkdir -p "$INFRA_DIR/npm"
    cp /tmp/worker-vm-skeleton/docker-apps/npm/docker-compose.yml "$INFRA_DIR/npm/"
    
    # Create portainer directory
    mkdir -p "$INFRA_DIR/portainer"
    cp /tmp/worker-vm-skeleton/docker-apps/portainer/docker-compose.yml "$INFRA_DIR/portainer/"
    
    # Set ownership
    chown -R "$WORKER_USERNAME:$WORKER_USERNAME" "$INFRA_DIR"
    
    log_info "Docker-compose files copied"
}

# Start infrastructure services
start_services() {
    log_info "Starting infrastructure services..."
    
    cd "$INFRA_DIR"
    
    # Start npm
    log_info "Starting nginx-proxy-manager..."
    cd npm
    docker compose up -d
    cd ..
    
    # Start portainer
    log_info "Starting Portainer..."
    cd portainer
    docker compose up -d
    cd ..
    
    log_info "Infrastructure services started"
}

# Create systemd services for auto-start
create_systemd_services() {
    log_info "Creating systemd services..."
    
    # Create npm service
    cat > /etc/systemd/system/npm.service << EOF
[Unit]
Description=nginx-proxy-manager
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$WORKER_USERNAME
WorkingDirectory=$INFRA_DIR/npm
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Create portainer service
    cat > /etc/systemd/system/portainer.service << EOF
[Unit]
Description=Portainer
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$WORKER_USERNAME
WorkingDirectory=$INFRA_DIR/portainer
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start services
    systemctl daemon-reload
    systemctl enable npm
    systemctl enable portainer
    
    log_info "Systemd services created and enabled"
}

# Create helper scripts for macseem
create_helper_scripts() {
    log_info "Creating helper scripts..."
    
    MACSEEM_HOME=$(eval echo ~$MACSEEM_USERNAME)
    
    # Create start script
    cat > "$MACSEEM_HOME/docker-apps/start.sh" << 'EOF'
#!/bin/bash
# Start all services
for dir in */; do
    if [[ -f "$dir/docker-compose.yml" ]]; then
        echo "Starting $dir..."
        (cd "$dir" && docker compose up -d)
    fi
done
EOF
    chmod +x "$MACSEEM_HOME/docker-apps/start.sh"
    
    # Create stop script
    cat > "$MACSEEM_HOME/docker-apps/stop.sh" << 'EOF'
#!/bin/bash
# Stop all services
for dir in */; do
    if [[ -f "$dir/docker-compose.yml" ]]; then
        echo "Stopping $dir..."
        (cd "$dir" && docker compose down)
    fi
done
EOF
    chmod +x "$MACSEEM_HOME/docker-apps/stop.sh"
    
    # Create logs script
    cat > "$MACSEEM_HOME/docker-apps/logs.sh" << 'EOF'
#!/bin/bash
# Show logs for a service
if [[ -z "$1" ]]; then
    echo "Usage: ./logs.sh <service-name>"
    exit 1
fi

cd "$1" && docker compose logs -f
EOF
    chmod +x "$MACSEEM_HOME/docker-apps/logs.sh"
    
    chown "$MACSEEM_USERNAME:$MACSEEM_USERNAME" "$MACSEEM_HOME/docker-apps/"*.sh
    
    log_info "Helper scripts created"
}

# Display summary
display_summary() {
    VM_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    log_info "========================================"
    log_info "Setup Complete!"
    log_info "========================================"
    echo ""
    log_info "Services:"
    log_info "  Portainer: https://portainer.$DOMAIN"
    log_info "  NPM Admin: http://$VM_IP:81"
    echo ""
    log_info "NPM Default Credentials:"
    log_info "  Email:    admin@example.com"
    log_info "  Password: changeme"
    echo ""
    log_info "Next Steps:"
    log_info "  1. Configure NPM with Cloudflare SSL certs"
    log_info "  2. Set up portainer.$DOMAIN proxy host"
    log_info "  3. Access Portainer and create admin user"
    log_info "  4. Start deploying your apps!"
    echo ""
    log_info "Helper scripts available in ~/docker-apps/"
    log_info "  ./start.sh   - Start all services"
    log_info "  ./stop.sh    - Stop all services"
    log_info "  ./logs.sh <name> - View service logs"
    echo ""
}

# Main installation
main() {
    log_info "Starting infrastructure installation..."
    
    copy_docker_files
    start_services
    create_systemd_services
    create_helper_scripts
    display_summary
    
    log_info "Installation complete!"
}

main
