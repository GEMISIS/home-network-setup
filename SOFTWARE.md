# Software Configuration Guide

This document describes the software components and logical flows required to implement the network layout defined in [ARCH.md](ARCH.md). It focuses on how services on the NixOS router interact with each VLAN and how unmanaged switches and management devices tie into the design.

## Required Software

| Layer | Software | Purpose |
|-------|----------|---------|
| Operating System | **NixOS** | Declarative host for router and services |
| Routing & Firewall | **nftables** with NixOS firewall | IPv4/IPv6 forwarding, NAT and inter‑VLAN policy |
| DHCP & DNS | **dnsmasq** | Per‑VLAN address pools and local DNS cache |
| VPN (remote management) | **WireGuard** | Secure access into VLAN 70 |
| WAP management | **UniFi Controller** | Adopt and manage access points on VLAN 50 |
| Log shipping | _Disabled (was Promtail → Loki)_ | Local log storage on the router |
| Intrusion prevention | _Disabled (was CrowdSec with nftables bouncer)_ | Brute‑force and bot protection |
| Optional advanced DHCP/DNS | **Kea** + **Unbound** | Replace dnsmasq when split services are required |

## Software Integration

```mermaid
flowchart LR
    %% Router services
    subgraph Router["NixOS Router"]
        NF["nftables"]
        DM["dnsmasq"]
        WG["WireGuard"]
        UC["UniFi Controller"]
        PR["Promtail (disabled)"]
        CS["CrowdSec (disabled)"]
        LK["Loki (disabled)"]
    end

    %% Networks
    subgraph DHCPVLANs["DHCP VLANs"]
        IoT["IoT</br>VLAN 10"]
        Auto["Automation</br>VLAN 20"]
        Guest["Guest</br>VLAN 30"]
        Family["Family</br>VLAN 40"]
        Media["Media</br>VLAN 50"]
        Cameras["Cameras</br>VLAN 60</br>(untagged)"]
        Mgmt["Mgmt PCs</br>VLAN 70"]
    end
    HA["Home Assistant</br>VLAN 50</br>static IP"]

    ISP["ISP / Internet"]

    WAPs["UniFi APs</br>Mgmt VLAN 50"]

    %% Service links
    DHCPVLANs -->|"DHCP/DNS"| DM
    HA -->|"DNS"| DM
    DHCPVLANs -->|"Firewall rules"| NF
    HA -->|"Firewall rules"| NF
    NF -->|"NAT & filtering"| ISP
    WG -->|"Remote access"| Mgmt
    WAPs -->|"Adoption & mgmt"| UC
    NF -.->|"logs"| PR
    DM -.->|"logs"| PR
    WG -.->|"logs"| PR
    CS -.->|"logs"| PR
    PR -.->|"push"| LK
    Mgmt -.->|"HTTP"| LK
    CS -.->|"Blocks"| NF
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

### enp1s0 – Trunk to APs & Tagged Devices (VLANs 10/20/30/40/50)
```mermaid
flowchart TD
    A[Client sends frame] --> B{Tagged?}
    B -- yes --> C[Use existing VLAN]
    B -- no --> F[Assign VLAN 50]
    C --> G[dnsmasq provides IP for VLAN]
    F --> G
    G --> H[nftables evaluates policy]
    H --> I{Internet allowed?}
    I -- yes --> J[NAT via enp8s0]
    I -- no --> K[Local VLAN only]
```

### enp2s0 – Camera Link (VLAN 60)
```mermaid
flowchart TD
    A[Camera sends untagged frame] --> B[enp2s0 assigns VLAN 60]
    B --> C[dnsmasq issues 192.168.60.x]
    C --> D[nftables blocks WAN access]
    D --> E[Traffic allowed only to HA 192.168.50.10]
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

### Home Assistant – VLAN 50 (Static IP)
```mermaid
flowchart TD
    A[HA sends untagged frame] --> B[Already in VLAN 50]
    B --> C[Static IP 192.168.50.10]
    C --> D[nftables allows LAN/WAN]
    D --> E[NAT via enp8s0]
```

Home Assistant uses a fixed address but still traverses nftables for policy enforcement and NAT for internet access.

## Management Access

```mermaid
flowchart LR
    AdminPC["Admin PC</br>VLAN 70"]
    FamilyPC["Family Device</br>VLAN 40"]
    HA["Home Assistant</br>VLAN 50"]
    WGUser["Remote Admin</br>WireGuard"]
    Others["Other VLANs"]
    subgraph RouterBox["Router"]
        Router["SSH / HTTPS"]
        Loki["Loki log store (disabled)"]
    end

    WGUser -->|"WireGuard"| Router
    AdminPC -->|"Direct 10 G"| Router
    FamilyPC -->|"SSH"| Router
    HA -.-|"blocked"| Router
    Others -.-|"blocked"| Router
    Router -. "logs via Promtail (disabled)" .-> Loki
    AdminPC -.->|"HTTP"| Loki
    WGUser -.->|"HTTP"| Loki
```

Only devices in VLAN 40 and VLAN 70 (or over WireGuard) may SSH into the router; nftables blocks all other VLANs.

## Unmanaged Switch Behaviour

```mermaid
flowchart LR
    subgraph Switch[Unmanaged Switch]
        HA["Home Assistant</br>(untagged)"]
        Media["Media Player</br>(untagged)"]
        Tagged["Tagged Device"]
    end
    Router["Router trunk port</br>native → VLAN 50"]

    HA -->|"Untagged"| Switch -->|"VLAN 50"| Router
    Media -->|"Untagged"| Switch -->|"VLAN 50"| Router
    Tagged -->|"Tagged VLAN"| Switch -->|"Preserves tag"| Router
```

*Each router interface except the WAN uplink uses an unmanaged switch; `enp7s0` may connect directly to a single host.*

---

This guide, paired with the physical layout in `ARCH.md`, ensures both software and hardware aspects of the network are fully defined.
