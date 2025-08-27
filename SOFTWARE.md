# Software Configuration Guide

This document describes the software components and logical flows required to implement the network layout defined in [ARCH.md](ARCH.md). It focuses on how services on the NixOS router interact with each VLAN and how unmanaged switches and management devices tie into the design.

## Required Software

| Layer | Software | Purpose |
|-------|----------|---------|
| Operating System | **NixOS** | Declarative host for router and services |
| Routing & Firewall | **nftables** with NixOS firewall | IPv4/IPv6 forwarding, NAT and inter‑VLAN policy |
| DHCP & DNS | **dnsmasq** | Per‑VLAN address pools and local DNS cache |
| VPN (remote management) | **WireGuard** | Secure access into VLAN 70 |
| Log shipping | **Promtail** → Loki | Centralised logging in management VLAN |
| Intrusion prevention | **CrowdSec** with nftables bouncer | Brute‑force and bot protection |
| Optional advanced DHCP/DNS | **Kea** + **Unbound** | Replace dnsmasq when split services are required |

## Software Integration

```mermaid
flowchart LR
    %% Router services
    subgraph Router["NixOS Router"]
        NF["nftables"]
        DM["dnsmasq"]
        WG["WireGuard"]
        PR["Promtail"]
        CS["CrowdSec"]
    end

    %% Networks
    subgraph DHCPVLANs["DHCP VLANs"]
        IoT["IoT\nVLAN 10"]
        Auto["Automation\nVLAN 20"]
        Guest["Guest\nVLAN 30"]
        Family["Family\nVLAN 40"]
        Media["Media\nVLAN 50"]
        Cameras["Cameras\nVLAN 60"]
        Mgmt["Mgmt PCs\nVLAN 70"]
    end
    HA["Home Assistant\nVLAN 51\nstatic IP"]

    ISP["ISP / Internet"]
    Loki["Loki Log Store"]

    %% Service links
    DHCPVLANs -->|"DHCP/DNS"| DM
    HA -->|"DNS"| DM
    DHCPVLANs -->|"Firewall rules"| NF
    HA -->|"Firewall rules"| NF
    NF -->|"NAT & filtering"| ISP
    WG -->|"Remote access"| Mgmt
    PR -->|"Logs"| Loki
    CS -->|"Blocks"| NF
```

## Interface IP & Connectivity Flows

### enp8s0 – WAN
```mermaid
flowchart TD
    A[Link up] --> B[DHCP from ISP]
    B --> C[Public IP assigned]
    C --> D[Default route created]
    D --> E{Inbound allowed?}
    E -- no --> F[Drop unsolicited traffic]
    E -- yes --> G[Port‑forward / WireGuard]
```

### enp1s0 – Trunk to APs & Tagged Devices (VLANs 10/20/30/40/50/51)
```mermaid
flowchart TD
    A[Client sends frame] --> B{Tagged?}
    B -- yes --> C[Use existing VLAN]
    B -- no --> D[Assign VLAN 50]
    C --> E[dnsmasq provides IP for VLAN]
    D --> E
    E --> F[nftables evaluates policy]
    F --> G{Internet allowed?}
    G -- yes --> H[NAT via enp8s0]
    G -- no --> I[Local VLAN only]
```

### enp2s0 – Camera Trunk (VLAN 60)
```mermaid
flowchart TD
    A[Camera sends VLAN 60 frame] --> B[enp2s0.60]
    B --> C[dnsmasq issues 192.168.60.x]
    C --> D[nftables blocks WAN access]
    D --> E[Traffic restricted to VLAN 51]
```

### enp7s0 – Management / Home‑Office (VLAN 70)
```mermaid
flowchart TD
    A[Mgmt device connects] --> B[enp7s0.70]
    B --> C[dnsmasq issues 192.168.70.x]
    C --> D[nftables allows admin services]
    D --> E[NAT via enp8s0]
```

The management VLAN always has internet access through NAT while still reaching administrative services on the router.

### Home Assistant – VLAN 51 (Static IP)
```mermaid
flowchart TD
    A[HA sends tagged frame] --> B[enp1s0.51]
    B --> C[Static IP 192.168.51.10]
    C --> D[nftables allows LAN/WAN]
    D --> E[NAT via enp8s0]
```

Home Assistant uses a fixed address but still traverses nftables for policy enforcement and NAT for internet access.

## Management Access

```mermaid
flowchart LR
    AdminPC["Admin PC<br/>VLAN 70"]
    FamilyPC["Family Device<br/>VLAN 40"]
    HA["Home Assistant<br/>VLAN 51"]
    WGUser["Remote Admin<br/>WireGuard"]
    Router["Router<br/>SSH / HTTPS"]
    Loki["Loki<br/>Log store"]
    Others["Other VLANs"]

    WGUser -->|"WireGuard"| Router
    AdminPC -->|"Direct 10 G"| Router
    FamilyPC -->|"SSH"| Router
    HA -.-|"blocked"| Router
    Others -.-|"blocked"| Router
    Router -- "logs via Promtail" --> Loki
```

Only devices in VLAN 40 and VLAN 70 (or over WireGuard) may SSH into the router; nftables blocks all other VLANs.

## Unmanaged Switch Behaviour

```mermaid
flowchart LR
    subgraph Switch[Unmanaged Switch]
        Device1["Tagged Device\n(e.g., Home Assistant)"]
        Device2["Untagged Device\n(e.g., Media Player)"]
    end
    Router["Router trunk port\ndefault → VLAN 50"]

    Device1 -->|"Tagged VLAN"| Switch -->|"Preserves tags"| Router
    Device2 -->|"Untagged"| Switch -->|"Assigned VLAN 50"| Router
```

*Each router interface except the WAN uplink uses an unmanaged switch; `enp7s0` may connect directly to a single host.*

---

This guide, paired with the physical layout in `ARCH.md`, ensures both software and hardware aspects of the network are fully defined.
