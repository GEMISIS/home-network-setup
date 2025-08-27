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
    subgraph Router["NixOS Router"]
        NF["nftables"]
        DM["dnsmasq"]
        WG["WireGuard"]
        PR["Promtail"]
        CS["CrowdSec"]
    end
    ISP["ISP / Internet"]
    WAPs["Wi‑Fi APs<br/>VLANs 10/20/30/40"]
    Media["Media Devices<br/>VLAN 50"]
    HA["Home Assistant<br/>VLAN 51"]
    Cameras["Security Cameras<br/>VLAN 60"]
    Mgmt["Mgmt PCs<br/>VLAN 70"]

    ISP -->|"enp8s0"| Router
    Router -->|"enp1s0 trunk"| WAPs
    Router -->|"enp1s0 VLAN50"| Media
    Router -->|"enp1s0 VLAN51"| HA
    Router -->|"enp2s0 VLAN60"| Cameras
    Router -->|"enp7s0 VLAN70"| Mgmt

    NF -.policies/.-> Router
    DM -.DHCP/DNS.- Router
    WG -.tunnel.- Mgmt
    PR -.logs.- Mgmt
    CS -.alerts.- NF
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
    A[Client sends tagged frame] --> B[Router sub‑interface enp1s0.<VLAN>]
    B --> C[dnsmasq provides IP for VLAN]
    C --> D[nftables evaluates policy]
    D --> E{Internet allowed?}
    E -- yes --> F[NAT via enp8s0]
    E -- no --> G[Local VLAN only]
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
    D --> E{Internet needed?}
    E -- yes --> F[NAT via enp8s0]
    E -- no --> G[Local mgmt only]
```

## Management Access

```mermaid
flowchart LR
    AdminPC["Admin PC<br/>VLAN 70"]
    WGUser["Remote Admin<br/>WireGuard"]
    Router["Router<br/>SSH / HTTPS"]
    Loki["Loki<br/>Log store"]

    WGUser -->|"WireGuard"| Router
    AdminPC -->|"Direct 10 G"| Router
    Router --> Loki
```

## Unmanaged Switch Behaviour

```mermaid
flowchart LR
    subgraph Switch[Unmanaged Switch]
        Device1[Tagged Device]
        Device2[Untagged Device]
    end
    Router["Router trunk port"]

    Device1 -->|"Tagged VLAN"| Switch -->|"Preserves tags"| Router
    Device2 -->|"Untagged"| Switch -->|"No native VLAN → frame dropped"| Router
```

*Devices must tag their own VLANs when attached through an unmanaged switch. Untagged traffic is discarded because trunk ports use no native VLAN (4095).* 

---

This guide, paired with the physical layout in `ARCH.md`, ensures both software and hardware aspects of the network are fully defined.
