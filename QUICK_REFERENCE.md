# Quick Reference Card

## Deployment Commands

```bash
# One-command full deployment
cd ~/multi-dc-evpn/containerlab
containerlab deploy --topo clab-topology.yml
sleep 30
cd ../tests && pytest test_fabric.py -v

# Interactive menu
./deploy.sh  # Run from project root

# Individual steps
# 1. Start topology
containerlab deploy --topo containerlab/clab-topology.yml

# 2. Run ansible
cd ansible
ansible-playbook -i inventory.yml deploy.yml --tags configure

# 3. Validate
cd ../tests
pytest test_fabric.py -v

# 4. Cleanup
cd ../containerlab
containerlab destroy --topo clab-topology.yml --cleanup
```

---

## Device IP Addresses

| Device | IP | SSH | Role |
|--------|----|----|------|
| dc1-spine1 | 172.20.20.2 | ssh admin@172.20.20.2 | RR |
| dc1-spine2 | 172.20.20.3 | ssh admin@172.20.20.3 | RR |
| dc1-leaf1 | 172.20.20.4 | ssh admin@172.20.20.4 | Leaf |
| dc1-leaf2 | 172.20.20.5 | ssh admin@172.20.20.5 | Leaf |
| dc1-leaf3 | 172.20.20.6 | ssh admin@172.20.20.6 | Leaf |
| dc1-leaf4 | 172.20.20.7 | ssh admin@172.20.20.7 | Leaf |
| dc2-spine1 | 172.20.20.8 | ssh admin@172.20.20.8 | RR |
| dc2-spine2 | 172.20.20.9 | ssh admin@172.20.20.9 | RR |
| dc2-leaf1 | 172.20.20.10 | ssh admin@172.20.20.10 | Leaf |
| dc2-leaf2 | 172.20.20.11 | ssh admin@172.20.20.11 | Leaf |
| dc2-leaf3 | 172.20.20.12 | ssh admin@172.20.20.12 | Leaf |
| dc2-leaf4 | 172.20.20.13 | ssh admin@172.20.20.13 | Leaf |

**Credentials:** admin / admin

---

## Critical BGP Verification Commands

```bash
# Check BGP summary (should show peers in Established state)
ssh admin@172.20.20.2 "show bgp summary"

# Check specific neighbor
ssh admin@172.20.20.2 "show bgp neighbors 10.1.0.1"

# Check EVPN routes
ssh admin@172.20.20.2 "show bgp evpn route-type mac-ip vlan 100"

# Check VXLAN tunnel
ssh admin@172.20.20.4 "show vxlan tunnel"

# Ping remote loopback
ssh admin@172.20.20.4 "ping 10.0.1.10 count 5"
```

---

## VLAN/VNI Quick Reference

```
Tenant1: VLANs 100-104, VNIs 10100-10104
Tenant2: VLANs 110-114, VNIs 10110-10114
Tenant3: VLANs 120-124, VNIs 10120-10124
Tenant4: VLANs 130-134, VNIs 10130-10134
Tenant5: VLANs 140-144, VNIs 10140-10144
L3 VRF:  VLAN 999,   VNI 999
```

---

## File Locations

```
~/multi-dc-evpn/
├── ansible/
│   ├── inventory.yml          → Device list
│   ├── deploy.yml            → Main playbook
│   ├── group_vars/           → DC/role config
│   └── host_vars/            → Device config
├── containerlab/
│   └── clab-topology.yml     → Topology
├── tests/
│   └── test_fabric.py        → Validation
├── docs/
│   ├── README.md             → Main guide
│   ├── DESIGN.md             → Architecture
│   └── TROUBLESHOOTING.md    → Fixes
└── deploy.sh                 → Quick deploy
```

---

## Ansible Quick Commands

```bash
# Check inventory
ansible-inventory -i ansible/inventory.yml --graph

# Ping all devices
ansible all -i ansible/inventory.yml -m ping

# Show BGP summary on spine1
ansible dc1_spines -i ansible/inventory.yml -m command -a "show bgp summary"

# Run playbook (interactive mode)
cd ansible
ansible-playbook deploy.yml

# Run playbook (specific host)
ansible-playbook deploy.yml -l dc1-spine1

# Run with tags
ansible-playbook deploy.yml --tags configure

# Dry-run (check mode)
ansible-playbook deploy.yml --check
```

---

## Docker/Container Commands

```bash
# Check container status
docker ps | grep clab-multi-dc-evpn

# View container logs
docker logs clab-multi-dc-evpn-dc1-spine1

# SSH into container
docker exec -it clab-multi-dc-evpn-dc1-spine1 bash

# Restart device
docker restart clab-multi-dc-evpn-dc1-spine1

# Clean up all containers
docker system prune -a

# List containerlab labs
containerlab ls

# Inspect topology
containerlab inspect -t containerlab/clab-topology.yml
```

---

## Testing Commands

```bash
# Run all tests
cd tests
pytest test_fabric.py -v

# Run specific test class
pytest test_fabric.py::TestBGPUnderlay -v

# Run specific test
pytest test_fabric.py::TestBGPUnderlay::test_dc1_spine1_bgp_established -v

# Run with output capture disabled (see prints)
pytest test_fabric.py -v -s

# Run with detailed traceback
pytest test_fabric.py -v --tb=long

# Run only tests matching pattern
pytest test_fabric.py -k "bgp" -v

# Generate HTML report
pytest test_fabric.py --html=report.html
```

---

## Network Validation Commands (on device)

```bash
# BGP
show bgp summary
show bgp neighbors
show bgp ipv4 unicast
show bgp evpn

# EVPN
show bgp evpn routes
show bgp evpn route-type mac-ip
show bgp evpn route-type inclusive-multicast

# VXLAN
show interface Vxlan1
show vxlan tunnel
show vxlan interface
show mac address-table

# Interface
show interfaces
show interfaces status
show ip interface brief

# Routing
show ip route
show ip route bgp
show ipv4 route

# Diagnostics
show lldp neighbors
show interfaces transceiver
ping <ip> count 5
traceroute <ip>
```

---

## Troubleshooting Quick Fixes

```bash
# Device won't start
containerlab destroy --topo containerlab/clab-topology.yml --cleanup
docker system prune -a
containerlab deploy --topo containerlab/clab-topology.yml

# BGP stuck in Connect state
# On device:
clear bgp ipv4 unicast * hard
clear bgp evpn * hard

# VXLAN tunnel not appearing
# Check:
show bgp evpn route-type inclusive-multicast
# Wait ~30 seconds for tunnels to be created

# Fabric won't converge
# Restart specific device:
docker restart clab-multi-dc-evpn-dc1-spine1
# Wait for it to come back online

# Can't SSH to device
# Check if running:
docker ps | grep dc1-spine1
# Wait longer (up to 90 seconds for boot)
```

---

## File Edit Quick Guide

```bash
# Edit inventory
nano ansible/inventory.yml

# Edit DC1 config
nano ansible/group_vars/dc1.yml

# Edit specific leaf
nano ansible/host_vars/dc1-leaf1.yml

# Edit topology
nano containerlab/clab-topology.yml

# Edit deployment playbook
nano ansible/deploy.yml

# Edit tests
nano tests/test_fabric.py
```

---

## Important Notes

- **Credentials:** Username=admin, Password=admin
- **Device Type:** Arista cEOS (containerlab)
- **BGP AS Numbers:** DC1=65000, DC2=65001
- **VXLAN Port:** 4789 (standard)
- **Management Network:** 172.20.20.0/24
- **Underlay DC1:** 10.1.0.0/16
- **Underlay DC2:** 10.2.0.0/16
- **Inter-DC:** 10.3.0.0/16

---

## Expected Output Examples

### Successful BGP Session
```
show bgp summary
Neighbor V AS MsgRcvd MsgSent InQ OutQ Up/Down State
10.1.0.1 4 65101 25 25 0 0 00:10:00 Established
```

### EVPN Routes Present
```
show bgp evpn routes
Total number of EVPN routes: 48
VNI: 10100 -> VRF: default
  Route Distinguisher: 65000:10.0.0.10 (dc1-leaf1)
  ...
```

### VXLAN Tunnel Created
```
show vxlan tunnel
VTEP Address      Tunnel Name       Src Intf   Src IP
10.0.0.11         Vxlan1            Loopback0  10.0.0.10
10.0.1.10         Vxlan1            Loopback0  10.0.0.10
```

---

## Project at a Glance

| Component | Count | Details |
|-----------|-------|---------|
| Devices | 12 | 4 spines, 8 leaves |
| Hosts | 8 | 4 per DC |
| VLANs | 50 | 25 per DC (5T×5V) |
| BGP Neighbors | 32 | Underlay + overlay |
| VXLAN Tunnels | ~60 | Per-VNI per-VTEP |
| Config Files | 20 | YAML-based |
| Test Cases | 15+ | Pytest-based |
| Docs | 8000+ lines | Complete reference |

---

**Last Updated:** February 2026  
**Print this for quick reference!**
