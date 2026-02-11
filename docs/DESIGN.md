# Multi-DC EVPN Fabric - Design Document

## Overview

Multi-datacenter VXLAN/EVPN fabric with:
- Per-DC autonomous systems (AS 65000 for DC1, AS 65001 for DC2)
- eBGP underlay with BGP unnumbered spine-leaf topology
- EVPN overlay with per-DC RR (route reflector) architecture
- Multi-tenant segmentation (5 tenants × 5 VLANs each)
- Symmetric IRB for inter-tenant routing
- Full infrastructure-as-code with Ansible/AVD
- Containerlab-based testing and validation

---

## Detailed Network Design

### 1. BGP Underlay Architecture

#### Design Goals
- eBGP on all links (no iBGP at leaf layer)
- Easy to scale with new leaves
- Fast convergence on failover

#### Topology
```mermaid
graph TD
    subgraph DC1["DC1 UNDERLAY (AS 65000)<br/>Loopback: 10.0.0.0/24 | P2P: 10.1.0.0/16"]
        S1["dc1-spine1<br/>10.0.0.1<br/>AS 65000"]
        S2["dc1-spine2<br/>10.0.0.2<br/>AS 65000"]
        
        L1["dc1-leaf1<br/>10.0.0.10<br/>AS 65101"]
        L2["dc1-leaf2<br/>10.0.0.11<br/>AS 65102"]
        L3["dc1-leaf3<br/>10.0.0.12<br/>AS 65103"]
        L4["dc1-leaf4<br/>10.0.0.13<br/>AS 65104"]
        
        S1 -->|E1: 10.1.0.0/31| L1
        S1 -->|E2: 10.1.0.2/31| L2
        S1 -->|E3: 10.1.0.4/31| L3
        S1 -->|E4: 10.1.0.6/31| L4
        
        S2 -->|E1: 10.1.1.0/31| L1
        S2 -->|E2: 10.1.1.2/31| L2
        S2 -->|E3: 10.1.1.4/31| L3
        S2 -->|E4: 10.1.1.6/31| L4
    end
    
    style S1 fill:#fff9c4
    style S2 fill:#fff9c4
    style L1 fill:#b3e5fc
    style L2 fill:#b3e5fc
    style L3 fill:#b3e5fc
    style L4 fill:#b3e5fc
```

#### BGP Configuration Example (dc1-spine1)

```
router bgp 65000
  bgp log-neighbor-changes
  neighbor 10.1.0.1 remote-as 65101      # dc1-leaf1
  neighbor 10.1.0.3 remote-as 65102      # dc1-leaf2
  neighbor 10.1.0.5 remote-as 65103      # dc1-leaf3
  neighbor 10.1.0.7 remote-as 65104      # dc1-leaf4
  !
  address-family ipv4 unicast
    redistribute connected
    neighbor 10.1.0.1 activate
    neighbor 10.1.0.3 activate
    neighbor 10.1.0.5 activate
    neighbor 10.1.0.7 activate
  exit-address-family
```

#### Inter-DC Peering

DC1 and DC2 spines peer via eBGP for EVPN reachability:

```
DC1-Spine1 (AS 65000) ←→ DC2-Spine1 (AS 65001)  [10.3.0.0/31]
DC1-Spine1 (AS 65000) ←→ DC2-Spine2 (AS 65001)  [10.3.0.2/31]
DC1-Spine2 (AS 65000) ←→ DC2-Spine1 (AS 65001)  [10.3.0.4/31]
DC1-Spine2 (AS 65000) ←→ DC2-Spine2 (AS 65001)  [10.3.0.6/31]
```

This allows DC1 leaves to advertise routes to DC2 leaves and vice versa.

---

### 2. EVPN Overlay Architecture

#### Overlay Goals
- **Isolation:** Per-DC EVPN domains with inter-DC connectivity
- **Scalability:** RR architecture vs full-mesh
- **Multi-tenancy:** VRF per tenant (extensible)

#### Design Pattern: iBGP with Route Reflectors

```mermaid
graph TD
    subgraph DC1["DC1 OVERLAY (AS 65000)<br/>All devices use same AS for iBGP"]
        RR["Route Reflectors<br/>Spines with RR enabled<br/>Cluster ID: 10.0.0.1"]
        
        L1["dc1-leaf1<br/>iBGP Client"]
        L2["dc1-leaf2<br/>iBGP Client"]
        L3["dc1-leaf3<br/>iBGP Client"]
        L4["dc1-leaf4<br/>iBGP Client"]
        
        RR ---|iBGP| L1
        RR ---|iBGP| L2
        RR ---|iBGP| L3
        RR ---|iBGP| L4
        
        L1 ---|EVPN<br/>Routes| RR
        L2 ---|EVPN<br/>Routes| RR
        L3 ---|EVPN<br/>Routes| RR
        L4 ---|EVPN<br/>Routes| RR
    end
    
    style RR fill:#c8e6c9
    style L1 fill:#b3e5fc
    style L2 fill:#b3e5fc
    style L3 fill:#b3e5fc
    style L4 fill:#b3e5fc
```

#### EVPN Route Types Advertised

1. **Type 1 (EAD - Ethernet Auto-Discovery)**
   - Signals leaf is active in VLAN
   - Used for all-active multihoming (future)

2. **Type 2 (MAC/IP)**
   - Carries MAC+IP bindings
   - Enables MAC learning on remote VTEP

3. **Type 3 (Inclusive Multicast)**
   - VXLAN tunnel source
   - Remote VTEP discovery

4. **Type 4 (ES Route)**
   - For MLAG scenarios (not in scope)

5. **Type 5 (IP Prefix)**
   - Inter-tenant routing via symmetric IRB

#### RD/RT Scheme

```
Per-device RD:  ASN:Loopback0
    dc1-leaf1: 65000:10.0.0.10
    dc1-leaf2: 65000:10.0.0.11
    dc2-leaf1: 65001:10.0.1.10
    dc2-leaf2: 65001:10.0.1.11

Per-VLAN RT (export/import):
    For tenant1-vlan100:
        Route Target: 65000:10100
        All leaves in DC1 export/import
        DC2 leaves also import (for multi-DC)

Per-VRF RT (symmetric IRB):
    For default VRF:
        Route Target: 65000:999
        All spines/leaves export/import
```

---

### 3. Multi-Tenancy Design

#### Tenant Isolation

Each tenant has dedicated VLANs and routing context:

```
Tenant1:
  VLAN 100 → VNI 10100 → RT 65000:10100
  VLAN 101 → VNI 10101 → RT 65000:10101
  VLAN 102 → VNI 10102 → RT 65000:10102
  VLAN 103 → VNI 10103 → RT 65000:10103
  VLAN 104 → VNI 10104 → RT 65000:10104
  [Repeat for Tenants 2-5 with different VLAN/VNI ranges]

Traffic isolation:
  - Hosts in Tenant1 VLAN 100 cannot reach Tenant2 VLAN 100 (different RT)
  - Unless explicitly routed via inter-tenant gateway (L3)
```

#### VLAN/VNI Allocation

```
Tenant1: VLANs 100-104, VNIs 10100-10104
Tenant2: VLANs 110-114, VNIs 10110-10114
Tenant3: VLANs 120-124, VNIs 10120-10124
Tenant4: VLANs 130-134, VNIs 10130-10134
Tenant5: VLANs 140-144, VNIs 10140-10144
L3 VRF: VLAN 999, VNI 999 (symmetric IRB)
```

#### Per-Leaf Tenant Membership (Example: dc1-leaf1)

```
SVI Interfaces:
  VLAN 100.1: 192.168.100.1/24   (Tenant1)
  VLAN 101.1: 192.168.101.1/24   (Tenant1)
  VLAN 102.1: 192.168.102.1/24   (Tenant1)
  VLAN 103.1: 192.168.103.1/24   (Tenant1)
  VLAN 104.1: 192.168.104.1/24   (Tenant1)
  VLAN 110.1: 192.168.110.1/24   (Tenant2)
  ... (rest of tenants)

VXLAN Mappings:
  Ingress: 
    Host MAC from VLAN 100 → VNI 10100 encap
  Egress:
    VNI 10100 → VLAN 100 decap → Host
```

---

### 4. Symmetric IRB (Inter-Tenant Routing)

#### Concept

Enables inter-tenant routing (L3) with consistent ingress/egress:

```mermaid
sequenceDiagram
    participant HostA as Host A<br/>Tenant1, VLAN100
    participant Leaf1 as dc1-leaf1<br/>IRB Gateway
    participant Leaf2 as dc1-leaf2<br/>Tenant2 Owner
    participant HostB as Host B<br/>Tenant2, VLAN110
    
    HostA->>Leaf1: Send to 192.168.100.1<br/>(default gateway)
    activate Leaf1
    Leaf1->>Leaf1: Routing lookup<br/>Destination: 192.168.110.0/24
    Leaf1->>Leaf1: Encapsulate in VXLAN<br/>L3 VNI 999
    Leaf1->>Leaf2: VXLAN Tunnel
    deactivate Leaf1
    
    activate Leaf2
    Leaf2->>Leaf2: Decapsulate<br/>VXLAN L3 VNI 999
    Leaf2->>Leaf2: IRB Routing
    Leaf2->>HostB: Deliver to VLAN110
    deactivate Leaf2
    
    Note over Leaf1,Leaf2: Symmetric: Both leaves<br/>perform IRB routing
```

#### Configuration on Leaf

```
vrf definition TENANT_VRF
  rd 65000:999
  route-target export 65000:999
  route-target import 65000:999
  
interface VLAN 100
  vrf forwarding TENANT_VRF
  ip address 192.168.100.1 255.255.255.0
  
interface VLAN 110
  vrf forwarding TENANT_VRF
  ip address 192.168.110.1 255.255.255.0

interface Loopback1
  vrf forwarding TENANT_VRF
  ip address 10.0.0.110 255.255.255.255
  description "Anycast gateway IP for symmetric IRB"
```

---

### 5. VXLAN Tunneling

#### Tunnel Source Selection

```
All VXLAN tunnels source from Loopback0:
  dc1-leaf1: Tunnel source 10.0.0.10
  dc1-leaf2: Tunnel source 10.0.0.11
  dc1-leaf3: Tunnel source 10.0.0.12
  dc1-leaf4: Tunnel source 10.0.0.13
  dc2-leaf1: Tunnel source 10.0.1.10
  ... (etc)

Why Loopback0?
  ✓ Stable, doesn't change with interface flaps
  ✓ Routable via BGP underlay
  ✓ Independent of physical link topology
```

#### VXLAN Tunnel Establishment

```mermaid
sequenceDiagram
    participant L1 as dc1-leaf1<br/>10.0.0.10
    participant RR as DC1 Spines<br/>Route Reflectors
    participant ICS as Inter-DC<br/>Spines
    participant L2 as dc2-leaf1<br/>10.0.1.10
    
    Note over L1: Learns VNI 10100<br/>owner via EVPN
    
    L1->>RR: EVPN Type 3<br/>Inclusive Multicast
    RR->>ICS: Advertise EVPN routes
    ICS->>L2: Route reaches DC2
    
    Note over L1,L2: VXLAN Tunnel Created:<br/>10.0.0.10 → 10.0.1.10
    
    L1->>L2: Original Frame<br/>[ETH][IP:10.0.0.10→10.0.1.10]<br/>[UDP:4789][VXLAN]<br/>[Original VLAN100 Frame]
    
    L2->>L2: Decapsulate VXLAN<br/>Extract VLAN100 frame
    L2-->>L1: Bidirectional tunnel<br/>also active
```

#### VNI to VLAN Mapping

```
Configuration on each leaf:
  interface Vxlan1
    vxlan source-interface Loopback0
    vxlan udp-port 4789
    vxlan vlan 100 vni 10100
    vxlan vlan 101 vni 10101
    ... (repeat for all 25 VLANs per DC)
```

---

## Deployment Sequence

### Phase 1: Underlay Establishment
```mermaid
graph LR
    A["1. Deploy<br/>Topology"] --> B["2. Configure<br/>Loopbacks & P2P"]
    B --> C["3. Enable<br/>BGP"]
    C --> D["4. Verify<br/>Neighbors"]
    D --> E{All<br/>Established?}
    E -->|No| C
    E -->|Yes| F["✓ Phase 1<br/>Complete"]
    
    style A fill:#e1bee7
    style F fill:#c8e6c9
    style E fill:#fff9c4
```

### Phase 2: EVPN Overlay
```mermaid
graph LR
    A["1. Enable EVPN<br/>on Spines"] --> B["2. Enable EVPN<br/>on Leaves"]
    B --> C["3. Create VLANs"]
    C --> D["4. Configure<br/>SVIs"]
    D --> E["5. Enable VXLAN"]
    E --> F["6. Verify<br/>Routes"]
    F --> G{Routes<br/>Present?}
    G -->|No| E
    G -->|Yes| H["✓ Phase 2<br/>Complete"]
    
    style A fill:#e1bee7
    style H fill:#c8e6c9
    style G fill:#fff9c4
```

### Phase 3: Multi-Tenant Configuration
```mermaid
graph LR
    A["1. Configure<br/>VRF"] --> B["2. Configure<br/>SVIs"]
    B --> C["3. Enable<br/>Loopback1"]
    C --> D["4. Test<br/>Connectivity"]
    D --> E{Working?}
    E -->|No| C
    E -->|Yes| F["✓ Phase 3<br/>Complete"]
    
    style A fill:#e1bee7
    style F fill:#c8e6c9
    style E fill:#fff9c4
```

### Phase 4: Inter-DC Connectivity
```mermaid
graph LR
    A["1. Verify<br/>BGP Peers"] --> B["2. Verify<br/>VXLAN Tunnels"]
    B --> C["3. Test Host<br/>Across DCs"]
    C --> D["4. Run<br/>Tests"]
    D --> E{All<br/>Passing?}
    E -->|No| C
    E -->|Yes| F["✓ Complete<br/>Deployment"]
    
    style A fill:#e1bee7
    style F fill:#c8e6c9
    style E fill:#fff9c4
```

---

## Scalability & Future Enhancements

### Adding New Leaf
1. Create new host_vars file with unique:
   - Device name
   - Loopback IPs
   - ASN
   - P2P IPs
2. Add to containerlab topology
3. Ansible playbook handles rest

### Adding New Tenant
1. Create new VLAN/VNI ranges in group_vars
2. Configure SVIs per leaf
3. Define new RT values
4. No changes to existing tenants

### Adding New Datacenter
1. Define new fabric AS (65002, 65003, etc.)
2. Create new group_vars/dc{n}*.yml
3. Create new host_vars for all devices
4. Add inter-DC spines peering
5. Ansible handles deployment

### CloudVision Integration (Future)
- Onboard devices to CVP
- Use CloudVision for change approval
- Event-based alerting
- Automated rollback on config failure

### Segment Routing (Future)
- Replace ECMP with segment routing
- Enable Traffic Engineering (TE)
- Implement SR-MPLS or SR-IPv6

---

## Testing Strategy

### Unit Tests (per-device)
```
✓ BGP neighbor state
✓ Interface status
✓ Loopback reachability
✓ EVPN route count
```

### Integration Tests (fabric-level)
```
✓ Host-to-host in same VLAN
✓ Host-to-host in different VLANs (same tenant)
✓ Inter-tenant routing
✓ Multi-DC reachability
✓ Failover scenarios
```

### Stress Tests (future)
```
✓ 1000+ MAC addresses per VLAN
✓ Convergence time after spine failure
✓ Data plane traffic during reconvergence
```

---

## References

- [RFC 7432: BGP MPLS-Based Ethernet VPN (EVPN)](https://tools.ietf.org/html/rfc7432)
- [RFC 8365: A Unified Control Plane for EVPN Data Centers](https://tools.ietf.org/html/rfc8365)
- [Arista EVPN Configuration Guide](https://www.arista.com/)
- [Network Programmability with Arista](https://www.arista.com/)

---

**Document Version:** 1.0  
**Last Updated:** February 2026
