# Home Network Setup
This is a quick repository for how my home network is setup. It's designed to be written as configuration code and now uses a Nix flake with Home Manager to manage applications.

## Overview

There's a full architecture document located in ARCH.md, and detailed software flows in SOFTWARE.md, but as a brief overview, the network is segmented into various VLANs, with some of these not having access to the internet for security purposes. The goal is to only give internet access where needed:

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

Wireless access points connect directly to the router and set VLAN IDs for their clients; wired devices like media players and Home Assistant tag their own VLANs.

```mermaid
flowchart LR
    %% ── Nodes ────────────────────────────────────────────────
    ISP["Internet / ISP"]
    Router["Linux Router<br/>Firewall · DHCP · DNS (NixOS)"]
    WAPs["6× WAPs<br/>SSIDs: VLAN 10 / 20 / 30 / 40"]
    Media["Media Devices<br/>VLAN 50"]
    HA["Home Assistant<br/>VLAN 51"]
    Cameras["Security Cameras<br/>VLAN 60"]
    HomeOffice["Home-Office / Mgmt Network<br/>VLAN 70<br/>10 G enp7s0"]

    %% ── Links ────────────────────────────────────────────────
    ISP -->|"10 G enp8s0"| Router

    Router -->|"2.5 G enp1s0 (802.1Q trunk)<br/>VLANs 10 / 20 / 30 / 40 / 50 / 51"| WAPs
    Router -->|"2.5 G enp1s0 (VLAN 50)"| Media
    Router -->|"2.5 G enp1s0 (VLAN 51)"| HA
    Router -->|"2.5 G enp2s0<br/>VLAN 60"| Cameras
    Router -->|"10 G enp7s0"| HomeOffice
```

The network runs on an iKoolCore R2 Max right now, which has two 10G ports and two 2.5G ports. We break this out into multiple pieces, where most things are sharing the 2.5G ports, except for my office, which has the remaining full 10G port (since the other one is used for the actual ISP connection to prevent bottlenecking).

The main machine is running NixOS, and this repo contains its configurations. Fun fact: This entire setup was done in a Meta Quest 3 VR headset (yes, even building the USB Boot Stick!), hence why there's a security key for a Meta Quest 3 device. NixOS was chosen specifically for its ability to be done entirely in code, which allows for LLMs to write the majority of the configurations for me. This is why the ARCH.md file is critical to be accurate, so that the LLM can know exactly what is needed when building.
