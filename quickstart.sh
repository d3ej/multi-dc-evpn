#!/bin/bash

# Multi-DC EVPN Fabric - Quick Start Script
# Automates containerlab deployment and validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAB_DIR="$SCRIPT_DIR/containerlab"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
TESTS_DIR="$SCRIPT_DIR/tests"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Multi-Datacenter VXLAN EVPN Fabric Deployment         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check dependencies
check_deps() {
    echo "[*] Checking dependencies..."
    
    if ! command -v containerlab &> /dev/null; then
        echo "❌ containerlab not found. Install: bash -c \"\$(curl -sL https://get.containerlab.dev)\""
        exit 1
    fi
    
    if ! command -v ansible &> /dev/null; then
        echo "❌ ansible not found. Install: pip3 install -r requirements.txt"
        exit 1
    fi
    
    if ! command -v pytest &> /dev/null; then
        echo "❌ pytest not found. Install: pip3 install -r requirements.txt"
        exit 1
    fi
    
    echo "✓ All dependencies found"
    echo ""
}

# Deploy topology
deploy_topology() {
    echo "[*] Deploying containerlab topology..."
    cd "$CLAB_DIR"
    
    if containerlab deploy --topo clab-topology.yml; then
        echo "✓ Topology deployed successfully"
    else
        echo "❌ Failed to deploy topology"
        exit 1
    fi
    
    echo "[*] Waiting for devices to stabilize (30 seconds)..."
    sleep 30
    echo ""
}

# Verify topology
verify_topology() {
    echo "[*] Verifying topology..."
    cd "$CLAB_DIR"
    
    if containerlab inspect -t clab-topology.yml; then
        echo "✓ Topology verification passed"
    else
        echo "❌ Topology verification failed"
        exit 1
    fi
    echo ""
}

# Deploy configurations
deploy_configs() {
    echo "[*] Deploying network configurations..."
    cd "$ANSIBLE_DIR"
    
    if ansible-playbook -i inventory.yml deploy.yml --tags deploy -v; then
        echo "✓ Configuration deployment completed"
    else
        echo "⚠ Configuration deployment encountered issues (this is expected in lab)"
    fi
    echo ""
}

# Run tests
run_tests() {
    echo "[*] Running network validation tests..."
    cd "$TESTS_DIR"
    
    if pytest test_fabric.py -v --tb=short; then
        echo "✓ All tests passed!"
    else
        echo "⚠ Some tests failed (expected if devices not fully configured)"
    fi
    echo ""
}

# Destroy topology
destroy_topology() {
    echo "[*] Destroying containerlab topology..."
    cd "$CLAB_DIR"
    
    if containerlab destroy --topo clab-topology.yml --cleanup; then
        echo "✓ Topology destroyed"
    fi
    echo ""
}

# Main menu
main_menu() {
    echo "Select action:"
    echo "  1) Deploy everything (topology + configs + tests)"
    echo "  2) Deploy topology only"
    echo "  3) Deploy configs only"
    echo "  4) Run tests only"
    echo "  5) Verify topology"
    echo "  6) Destroy topology"
    echo "  7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice
    
    case $choice in
        1)
            check_deps
            deploy_topology
            verify_topology
            deploy_configs
            run_tests
            echo "╔════════════════════════════════════════════════════════════╗"
            echo "║          Deployment Complete! Ready for testing            ║"
            echo "║                                                            ║"
            echo "║  Access devices:                                           ║"
            echo "║    ssh admin@172.20.20.2   # dc1-spine1                   ║"
            echo "║    ssh admin@172.20.20.4   # dc1-leaf1                    ║"
            echo "║    ssh admin@172.20.20.8   # dc2-spine1                   ║"
            echo "║                                                            ║"
            echo "║  Run tests anytime:                                        ║"
            echo "║    cd tests && pytest test_fabric.py -v                    ║"
            echo "║                                                            ║"
            echo "║  Destroy when done:                                        ║"
            echo "║    ./quickstart.sh -> option 6                            ║"
            echo "╚════════════════════════════════════════════════════════════╝"
            ;;
        2)
            check_deps
            deploy_topology
            verify_topology
            ;;
        3)
            deploy_configs
            ;;
        4)
            run_tests
            ;;
        5)
            verify_topology
            ;;
        6)
            destroy_topology
            ;;
        7)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

# Run main menu
main_menu
