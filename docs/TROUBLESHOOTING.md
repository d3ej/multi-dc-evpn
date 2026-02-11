# Multi-DC EVPN Fabric - Troubleshooting Guide

## Common Issues & Solutions

### 1. Containerlab Topology Won't Start

#### Problem: `docker: command not found`
**Solution:**
```bash
# Install Docker
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
# Logout and login for group changes to take effect
```

#### Problem: `error when calling POST /containers/create: OCI runtime error`
**Solution:**
```bash
# Insufficient resources or cEOS image not available
docker pull arista/ceos:latest
# Or reduce container count in clab-topology.yml
```

#### Problem: Devices stuck in "created" state
**Solution:**
```bash
# Cleanup and redeploy
containerlab destroy --topo containerlab/clab-topology.yml --cleanup
docker system prune -a
containerlab deploy --topo containerlab/clab-topology.yml
```

---

### 2. SSH/Connectivity Issues

#### Problem: `ssh: connect to host 172.20.20.2 port 22: Connection refused`
**Solution:**
```bash
# Wait longer for device to boot (can take 60+ seconds)
sleep 90

# Check container status
docker ps | grep clab-multi-dc-evpn

# Check container logs
docker logs clab-multi-dc-evpn-dc1-spine1

# If still failing, device may have crashed - check image
docker logs clab-multi-dc-evpn-dc1-spine1 | tail -50
```

#### Problem: `Permission denied (publickey,password)`
**Solution:**
```bash
# Default cEOS credentials
Username: admin
Password: admin

# Ensure you're using correct credentials in Ansible
# Check ansible/inventory.yml for ansible_user/ansible_password

# Try manual SSH
ssh admin@172.20.20.2
# If password prompt appears, enter: admin
```

#### Problem: Ansible hosts unreachable
**Solution:**
```bash
# Verify IP configuration
containerlab inspect -t containerlab/clab-topology.yml

# Manually ping device
ping 172.20.20.2

# Check if running
docker exec clab-multi-dc-evpn-dc1-spine1 /bin/bash
```

---

### 3. BGP Issues

#### Problem: BGP neighbors stuck in Connect/OpenSent state
**Symptoms:**
```
show bgp summary
BGP router identifier 10.0.0.1, local AS number 65000
...
Neighbor V AS MsgRcvd MsgSent InQ OutQ Up/Down State
10.1.0.1 4 65101 0 0 0 0 00:00:10 Connect
```

**Solution:**
```bash
# Check interface status first
show interfaces Ethernet1
# If down, interface config is missing

# Check IP address on interface
show ip interface brief
# Should show: Ethernet1 10.1.0.0/31 up up

# Check BGP config
show bgp configuration
# Verify neighbor IP and AS number

# Check for BGP errors
show bgp neighbors 10.1.0.1
# Look for "Last write" and "Last read" timestamps
# If stuck, neighbor isn't responding

# Fix: ensure leaf has correct IP on corresponding interface
```

#### Problem: BGP neighbors up but no routes exchanged
**Symptoms:**
```
show bgp summary
BGP router identifier 10.0.0.1, local AS number 65000
...
Neighbor V AS MsgRcvd MsgSent InQ OutQ Up/Down State
10.1.0.1 4 65101 5 5 0 0 00:00:30 Established
```
**But:**
```
show bgp ipv4 unicast
Total number of IPv4 routes: 0
```

**Solution:**
```bash
# Verify address-family is activated
show bgp neighbors 10.1.0.1 advertised-routes

# Check if redistribution is enabled
show running-config | include redistribute

# Ensure device has routes to redistribute
show ip route

# Fix: add to BGP config
router bgp 65000
  address-family ipv4 unicast
    neighbor 10.1.0.1 activate
    redistribute connected
```

#### Problem: EVPN routes not appearing
**Symptoms:**
```
show bgp evpn summary
Neighbor V AS MsgRcvd MsgSent InQ OutQ Up/Down State
10.1.0.1 4 65101 100 100 0 0 00:05:00 Established

show bgp evpn routes
Total number of EVPN routes: 0
```

**Solution:**
```bash
# Verify EVPN address-family is enabled
show bgp evpn summary

# Check if address-family is activated on neighbors
show bgp evpn neighbors

# Ensure VLANs/SVIs are created (generates routes)
show vlan
show interfaces vlan

# Check VXLAN interface
show interface Vxlan1
# Should show state as "up"

# Fix sequence:
1. Create VLAN
2. Create SVI with IP
3. Enable VXLAN mapping
4. EVPN routes should appear within seconds
```

---

### 4. VXLAN Issues

#### Problem: VXLAN interface down
**Symptoms:**
```
show interface Vxlan1
Vxlan1 is down, line protocol is down
```

**Solution:**
```bash
# Check if source loopback exists and is up
show ip interface Loopback0
# Must be UP and have valid IP

# Check VXLAN config
show running-config interface Vxlan1
# Should have:
#   vxlan source-interface Loopback0
#   vxlan udp-port 4789
#   vxlan vlan 100 vni 10100 (etc)

# Verify loopback has IP
show ip interface brief
# Loopback0 should show IP address

# Fix: ensure Loopback0 is configured
int Loopback0
  ip address <loopback-ip> 255.255.255.255
```

#### Problem: VXLAN tunnel not created
**Symptoms:**
```
show vxlan tunnel
VTEP Address      Tunnel Name       Src Intf   Src IP          Index  RxPkts  TxPkts
<empty>
```

**Solution:**
```bash
# VXLAN tunnels created dynamically via EVPN learning
# If empty, means no remote VTEPs learned yet

# Check EVPN routes
show bgp evpn route-type inclusive-multicast
# Should show remote VTEPs for each VNI

# Example:
# RD: 65000:10.0.0.10 (dc1-leaf2)
# Originating IP: 10.0.0.11
# VNI: 10100

# If empty:
#   1. Check if remote leaf has EVPN enabled
#   2. Check if remote leaf has same VLAN
#   3. Check inter-DC peering is working

# Debug: check routes on upstream RR
# On spine1: show bgp evpn route-type inclusive-multicast
```

---

### 5. Multi-DC Connectivity Issues

#### Problem: Inter-DC BGP neighbors not established
**Symptoms:**
```
# On dc1-spine1
show bgp neighbors 10.3.0.1
# State: Connect or Idle
```

**Solution:**
```bash
# Check inter-DC interface status
show interfaces Ethernet5
# Must be UP

# Check IP config
show ip interface brief | grep Ethernet5
# Should show 10.3.0.0/31 (dc1-spine1 side)

# Verify remote device
show ip route
# Should have route to 10.3.0.0/31 subnet

# Check BGP config
show running-config | section "neighbor 10.3.0"

# Physical check:
# - Verify containerlab links in clab-topology.yml
# - Confirm both sides have matching P2P IPs (one is .0, other is .1)

# Fix: Ensure both ends of inter-DC link are up and have correct IPs
```

#### Problem: Tenant VLANs not extending to remote DC
**Symptoms:**
```
# On dc1-leaf1
show bgp evpn route-type mac-ip vlan 100
# Routes should include entries from DC2 leaves
# But DC2 entries are missing
```

**Solution:**
```bash
# Step 1: Verify local EVPN is working
show bgp evpn route-type mac-ip vlan 100
# Should see local routes

# Step 2: Check inter-DC RR (spine) has routes
ssh admin@172.20.20.2  # dc1-spine1
show bgp evpn route-type mac-ip vlan 100
# Should include DC2 routes via inter-DC peers

# Step 3: Check if DC2 is advertising
ssh admin@172.20.20.8  # dc2-spine1
show bgp evpn route-type mac-ip vlan 100
# Must be non-empty

# Step 4: Verify DC2 VLAN exists
show vlan
# VLAN 100 should exist

# Fix: If DC2 doesn't have VLAN 100, add it:
# See ../ansible/host_vars/dc2-leaf1.yml for VLAN config
```

---

### 6. Ansible Playbook Issues

#### Problem: `fatal: [dc1-spine1]: FAILED! => Connection refused`
**Solution:**
```bash
# Playbook can't reach device
# Ensure devices are running and IPs correct

# Check inventory
ansible-inventory -i ansible/inventory.yml --graph

# Manual connectivity test
ansible all -i ansible/inventory.yml -m ping
# If fails, SSH isn't working (see SSH section above)

# Ensure credentials are correct
# In ansible/inventory.yml, verify ansible_host IPs
```

#### Problem: `fatal: [dc1-spine1]: FAILED! => 'ascii' codec can't decode byte`
**Solution:**
```bash
# Usually means device returned non-ASCII characters
# Could be buffer issue or config error

# Check device config manually:
ssh admin@172.20.20.2
show running-config

# Retry playbook with more verbose output
ansible-playbook -i ansible/inventory.yml ansible/deploy.yml -vvv
```

#### Problem: Configuration not applied to devices
**Solution:**
```bash
# Verify playbook executed successfully
# Check if there were errors in output (red text)

# Manually verify on device:
ssh admin@172.20.20.2
show running-config interface Ethernet1

# If config missing, may need manual push or fix playbook

# Re-run playbook:
cd ansible
ansible-playbook -i inventory.yml deploy.yml --tags configure -vv
```

---

### 7. Test Failures

#### Problem: `pytest: test_dc1_spine1_bgp_established FAILED`
**Solution:**
```bash
# Run test with more detail:
pytest tests/test_fabric.py::TestBGPUnderlay::test_dc1_spine1_bgp_established -vv

# Manually verify on device:
ssh admin@172.20.20.2
show bgp summary
# Count number of neighbors that are "Established"

# If only 2 established but test expects 4:
# Some peers are still in Connect state
# See BGP section above for solutions
```

#### Problem: `VXLAN tunnel between DCs not working` (ping test fails)
**Solution:**
```bash
# Test assumes full VXLAN connectivity
# But tunnel takes time to establish

# Manually check:
ssh admin@172.20.20.4  # dc1-leaf1
ping 10.0.1.10 count 5
# May need to wait ~30 seconds for tunnel to form

# If tunnel still not working:
# Check EVPN Type 3 routes (inclusive multicast)
show bgp evpn route-type inclusive-multicast
# Should show entries for remote VXLAN tunnel source
```

---

## Diagnostic Commands Reference

### BGP Underlay
```bash
# Summary
show bgp summary

# Neighbor details
show bgp neighbors 10.1.0.1

# Advertised routes
show bgp neighbors 10.1.0.1 advertised-routes

# Received routes
show bgp neighbors 10.1.0.1 received-routes

# Routes in table
show bgp ipv4 unicast
```

### EVPN Overlay
```bash
# Summary
show bgp evpn summary

# All EVPN routes
show bgp evpn

# Routes by type
show bgp evpn route-type mac-ip
show bgp evpn route-type inclusive-multicast
show bgp evpn route-type ip-prefix

# Specific VLAN
show bgp evpn route-type mac-ip vlan 100
```

### VXLAN
```bash
# Interface status
show interface Vxlan1

# VNI mappings
show vxlan interface

# MAC address table (learned MACs)
show mac address-table

# Tunnel status
show vxlan tunnel

# Tunnel statistics
show vxlan tunnel endpoint
```

### Interface & IP
```bash
# Brief interface summary
show ip interface brief

# Detailed interface info
show interfaces Ethernet1

# Interface statistics
show interfaces Ethernet1 detail

# IP route
show ip route
show ip route bgp

# BGP prefixes only
show bgp ipv4 unicast summary
```

---

## Recovery Procedures

### Device Won't Boot
```bash
# Destroy and redeploy
cd containerlab
containerlab destroy --topo clab-topology.yml --cleanup
docker system prune -a
docker pull arista/ceos:latest
containerlab deploy --topo clab-topology.yml
```

### Fabric Won't Converge
```bash
# Restart BGP
ssh admin@172.20.20.2
clear bgp ipv4 unicast * hard
clear bgp evpn * hard

# Wait ~30 seconds for convergence
# Then verify
show bgp summary
```

### Complete Reset
```bash
# Start from scratch
cd containerlab
./../../deploy.sh cleanup

# Wait 30 seconds, then redeploy
./../../deploy.sh full
```

---

## Performance & Best Practices

### Monitoring Recommendations
- BGP flapping (frequent state changes)
- VXLAN tunnel count (should match remote VTEPs)
- MAC address table size
- CPU/memory on spine (RR bottleneck)

### Scaling Limits
- Per device: ~1M MAC addresses (depends on hardware)
- Per VLAN: ~10K MACs (practical limit)
- Inter-DC tunnels: 1 per remote leaf per VLAN

### Optimization Tips
- Enable `router bgp graceful-restart` for graceful failover
- Use BGP prefix-length for faster convergence
- Monitor BGP RIB size: `show bgp memory`

---

## Additional Resources

- Containerlab Docs: https://containerlab.dev
- Arista cEOS: https://www.arista.com/en/support/containered-eos
- BGP EVPN RFC: https://tools.ietf.org/html/rfc7432
- Ansible Docs: https://docs.ansible.com

**Last Updated:** February 2026
