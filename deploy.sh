#!/bin/bash
# Quick deployment script for multi-DC EVPN fabric

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLAB_DIR="$SCRIPT_DIR/containerlab"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
TESTS_DIR="$SCRIPT_DIR/tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker."
        exit 1
    fi
    print_success "Docker found"
    
    # Check containerlab
    if ! command -v containerlab &> /dev/null; then
        print_error "Containerlab not found. Installing..."
        bash -c "$(curl -sL https://get.containerlab.dev)"
    fi
    print_success "Containerlab available"
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible not found. Please install: pip3 install ansible"
        exit 1
    fi
    print_success "Ansible found"
    
    # Check Python packages
    if ! python3 -c "import netmiko" 2>/dev/null; then
        print_info "Installing Python dependencies..."
        pip3 install -r "$SCRIPT_DIR/requirements.txt"
    fi
    print_success "Python dependencies installed"
}

# Deploy topology
deploy_topology() {
    print_header "Deploying Containerlab Topology"
    
    cd "$CLAB_DIR"
    print_info "Starting containerlab topology..."
    containerlab deploy --topo clab-topology.yml
    
    print_success "Topology deployed successfully"
    print_info "Waiting 30 seconds for devices to stabilize..."
    sleep 30
}

# Deploy configurations
deploy_configs() {
    print_header "Deploying Network Configurations"
    
    cd "$ANSIBLE_DIR"
    print_info "Running Ansible deployment playbook..."
    
    # Check if inventory is reachable
    ansible-inventory -i inventory.yml --graph
    
    print_info "Deploying to DC1 and DC2..."
    ansible-playbook -i inventory.yml deploy.yml \
        -k \
        --tags "configure" \
        -v
    
    print_success "Configurations deployed"
}

# Run validation tests
run_tests() {
    print_header "Running Network Validation Tests"
    
    cd "$TESTS_DIR"
    print_info "Executing pytest suite..."
    
    if pytest test_fabric.py -v --tb=short; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed. Check output above."
        return 1
    fi
}

# Display topology info
show_topology() {
    print_header "Topology Information"
    
    cd "$CLAB_DIR"
    containerlab inspect -t clab-topology.yml
    
    print_info "Device credentials:"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    print_info "Access devices:"
    echo "  DC1-Spine1: ssh admin@172.20.20.2"
    echo "  DC1-Leaf1:  ssh admin@172.20.20.4"
    echo "  DC2-Spine1: ssh admin@172.20.20.8"
    echo "  DC2-Leaf1:  ssh admin@172.20.20.10"
}

# Cleanup
cleanup() {
    print_header "Cleaning Up"
    
    cd "$CLAB_DIR"
    print_info "Destroying containerlab topology..."
    containerlab destroy --topo clab-topology.yml --cleanup
    
    print_success "Cleanup complete"
}

# Main menu
show_menu() {
    echo ""
    echo "Multi-DC EVPN Fabric Management"
    echo "=================================="
    echo "1. Check prerequisites"
    echo "2. Deploy topology"
    echo "3. Deploy configurations"
    echo "4. Run validation tests"
    echo "5. Show topology info"
    echo "6. Full deployment (1-5)"
    echo "7. Cleanup (destroy topology)"
    echo "8. Exit"
    echo ""
}

# Main logic
main() {
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1) check_prerequisites ;;
                2) deploy_topology ;;
                3) deploy_configs ;;
                4) run_tests ;;
                5) show_topology ;;
                6) 
                    check_prerequisites
                    deploy_topology
                    show_topology
                    ;;
                7) cleanup ;;
                8) 
                    print_info "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option. Please try again."
                    ;;
            esac
        done
    else
        # Command line mode
        case "$1" in
            check) check_prerequisites ;;
            deploy) deploy_topology ;;
            config) deploy_configs ;;
            test) run_tests ;;
            info) show_topology ;;
            full) 
                check_prerequisites
                deploy_topology
                show_topology
                ;;
            cleanup) cleanup ;;
            *)
                echo "Usage: $0 [check|deploy|config|test|info|full|cleanup]"
                exit 1
                ;;
        esac
    fi
}

# Run main
main "$@"
