# Home Network Setup
This is a quick repository for how my home network is setup. It's designed to be written as a configuration code, and utilizes AI to help manage its setup.

## Overview

There's a full architecture document located in ARCH.md, but as a brief overview, the network is segmented into various VLANs, with some of these not having access to the internet for security purposes. The goal is to only give internet access where needed:

| VLAN | Purpose                       | Internet Access | Notes |
|------|------------------------------|-----------------|-------|
| 10   | Internet-only IoT devices    | ✔︎              | Wi‑Fi SSID #1 |
| 20   | Home‑automation devices      | ✖︎              | Wi‑Fi SSID #2 |
| 30   | Guest network                | ✔︎              | Wi‑Fi SSID #3 |
| 40   | Home‑user devices            | ✔︎              | Wi‑Fi SSID #4 |
| 50   | Media (Apple TV, consoles)   | ✔︎              | Wired only |
| 51   | Home‑Assistant               | ✔︎              | Wired only |
| 60   | Security cameras             | ✖︎              | Wired, dedicated NIC |
| 70   | Home‑office / Management     | ✔︎ (optional)   | Private 10 G link |

```mermaid
flowchart LR
    %% ── Nodes ────────────────────────────────────────────────
    ISP["Internet / ISP"]
    Router["Linux Router<br/>Firewall · DHCP · DNS (NixOS)"]
    SwitchNode["Managed Switch"]
    WAPs["6× WAPs<br/>SSIDs: VLAN 10 / 20 / 30 / 40"]
    Media["Media Devices<br/>VLAN 50"]
    HA["Home Assistant<br/>VLAN 51"]
    Cameras["Security Cameras<br/>VLAN 60"]
    HomeOffice["Home-Office / Mgmt Network<br/>VLAN 70<br/>10 G enp2s0"]

    %% ── Links ────────────────────────────────────────────────
    ISP -->|"10 G enp1s0"| Router

    Router -->|"2.5 G enp3s0 (trunk)<br/>VLAN 10 / 20 / 30 / 40 / 50 / 51"| SwitchNode
    Router -->|"2.5 G enp4s0<br/>VLAN 60"| Cameras
    Router -->|"10 G enp2s0"| HomeOffice

    SwitchNode -->|"Tagged VLAN 10 / 20 / 30 / 40"| WAPs
    SwitchNode -->|"Untagged VLAN 50"| Media
    SwitchNode -->|"Untagged VLAN 51"| HA
```

The network runs on an iKoolCore R2 Max right now, which has two 10G ports and two 2.5G ports. We break this out into multiple pieces, where most things are sharing the 2.5G ports, except for my office, which has the remaining full 10G port (since the other one is used for the actual ISP connection to prevent bottlenecking).
