#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if ansible is installed
check_prerequisites() {
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible is not installed. Please install it first:"
        log_error "  pip install ansible"
        exit 1
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        log_error "ansible-playbook is not found"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Check if vault file is encrypted
check_vault() {
    local vault_file="${ANSIBLE_DIR}/inventory/group_vars/all/vault.yml"
    
    if [[ ! -f "$vault_file" ]]; then
        log_error "Vault file not found: $vault_file"
        log_error "Please create and encrypt it: ansible-vault create inventory/group_vars/all/vault.yml"
        exit 1
    fi

    # Check if file is encrypted (starts with $ANSIBLE_VAULT)
    if head -1 "$vault_file" | grep -q "^\$ANSIBLE_VAULT"; then
        log_info "Vault file is encrypted ✓"
        return 0
    else
        log_warn "Vault file is NOT encrypted!"
        log_warn "Please encrypt it before running: ansible-vault encrypt inventory/group_vars/all/vault.yml"
        read -p "Do you want to encrypt it now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ansible-vault encrypt "$vault_file"
            log_info "Vault file encrypted"
        else
            log_error "Cannot run without encrypted vault. Exiting."
            exit 1
        fi
    fi
}

# Check inventory configuration
check_inventory() {
    local inventory_file="${ANSIBLE_DIR}/inventory/hosts.yml"
    
    if [[ ! -f "$inventory_file" ]]; then
        log_error "Inventory file not found: $inventory_file"
        exit 1
    fi

    log_info "Inventory file found ✓"
}

# Check host IP configuration
check_host_ip() {
    local host_ip_file="${ANSIBLE_DIR}/host_ip.conf"
    local host_ip_template="${ANSIBLE_DIR}/host_ip.conf.template"
    
    if [[ ! -f "$host_ip_file" ]]; then
        log_error "Host IP configuration not found: $host_ip_file"
        log_error "Please create it from the template:"
        log_error "  cp host_ip.conf.template host_ip.conf"
        log_error "  # Then edit host_ip.conf and set your VM's IP address"
        exit 1
    fi

    # Source the file to get TARGET_HOST
    source "$host_ip_file"
    
    if [[ -z "$TARGET_HOST" ]] || [[ "$TARGET_HOST" == "your.vm.ip.address.here" ]]; then
        log_error "TARGET_HOST is not set in $host_ip_file"
        log_error "Please edit $host_ip_file and set your VM's IP address"
        exit 1
    fi

    log_info "Target host: $TARGET_HOST ✓"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run Ansible playbook to provision the worker VM.

PREREQUISITES:
    1. Create host_ip.conf from template:
       cp host_ip.conf.template host_ip.conf
       # Edit and set TARGET_HOST=your.vm.ip.address

    2. Create and encrypt vault.yml with your secrets

OPTIONS:
    -p, --password-file FILE    Use vault password from FILE
    -t, --tags TAGS             Run only specific tags (comma-separated)
    -c, --check                 Run in check mode (dry run)
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    # Run with interactive password prompt
    $0

    # Use password file
    $0 -p .vault_pass

    # Run only docker and users roles
    $0 -t docker,users

    # Dry run to see what would change
    $0 -c

    # Verbose output with password file
    $0 -p .vault_pass -v

EOF
}

# Parse arguments
VAULT_PASS_FILE=""
EXTRA_OPTS=""
CHECK_MODE=""
VERBOSE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--password-file)
            VAULT_PASS_FILE="$2"
            shift 2
            ;;
        -t|--tags)
            EXTRA_OPTS="${EXTRA_OPTS} --tags $2"
            shift 2
            ;;
        -c|--check)
            CHECK_MODE="--check"
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main
main() {
    log_info "Worker VM Provisioning Script"
    log_info "=============================="
    echo

    check_prerequisites
    check_inventory
    check_host_ip
    check_vault

    echo
    log_info "Starting Ansible playbook..."
    echo

    cd "${ANSIBLE_DIR}"

    # Source host_ip.conf to get TARGET_HOST
    source "${ANSIBLE_DIR}/host_ip.conf"

    # Build ansible-playbook command
    local cmd="ansible-playbook -i inventory/hosts.yml site.yml -e \"target_host=${TARGET_HOST}\""
    
    if [[ -n "$VAULT_PASS_FILE" ]]; then
        if [[ ! -f "$VAULT_PASS_FILE" ]]; then
            log_error "Password file not found: $VAULT_PASS_FILE"
            exit 1
        fi
        cmd="${cmd} --vault-password-file ${VAULT_PASS_FILE}"
    fi

    if [[ -n "$EXTRA_OPTS" ]]; then
        cmd="${cmd} ${EXTRA_OPTS}"
    fi

    if [[ -n "$CHECK_MODE" ]]; then
        cmd="${cmd} ${CHECK_MODE}"
        log_warn "Running in CHECK MODE (dry run)"
    fi

    if [[ -n "$VERBOSE" ]]; then
        cmd="${cmd} ${VERBOSE}"
    fi

    log_info "Running: ${cmd}"
    echo

    eval "${cmd}"

    echo
    log_info "Playbook completed successfully!"
    
    # Check if output directory has keys
    if [[ -d "${ANSIBLE_DIR}/output" ]]; then
        local key_count=$(find "${ANSIBLE_DIR}/output" -name "*_key" -type f | wc -l)
        if [[ $key_count -gt 0 ]]; then
            echo
            log_info "SSH Private Keys saved to:"
            find "${ANSIBLE_DIR}/output" -name "*_key" -type f | while read -r key; do
                echo "  - ${key}"
            done
        fi
    fi
}

main "$@"
