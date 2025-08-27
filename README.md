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
| 51   | Home‑Assistant               | ✔︎              | Untagged · static IP |
| 60   | Security cameras             | ✖︎              | Untagged on dedicated NIC |
| 70   | Home‑office / Management     | ✔︎ (optional)   | Private 10 G link |

Wireless access points tag VLAN IDs for their clients. Wired devices connect through unmanaged switches; untagged traffic lands in VLAN 50 by default. The router uses MAC rules to place the Home Assistant server in VLAN 51 and cameras on VLAN 60.

```mermaid
flowchart LR
    ISP["Internet / ISP"] -->|"10 G enp8s0"| Router["Linux Router<br/>Firewall · DHCP · DNS (NixOS)"]

    Router -->|"2.5 G"| enp1s0["enp1s0 trunk\nnative → VLAN 50"]
    enp1s0 --> SW1["Unmanaged Switch"]
    SW1 -->|"Tagged 10/20/30/40"| WAPs["6× WAPs\nSSIDs: VLAN 10 / 20 / 30 / 40"]
    SW1 -->|"Untagged → VLAN 50"| Media["Media Devices\nVLAN 50 / Untagged"]
    SW1 -->|"Untagged (MAC → VLAN 51)"| HA["Home Assistant\nStatic 192.168.51.10"]

    Router -->|"2.5 G"| enp2s0["enp2s0\nuntagged → VLAN 60"]
    enp2s0 --> SW2["Unmanaged Switch"]
    SW2 -->|"Untagged → VLAN 60"| Cameras["Security Cameras\n(Untagged)"]

    Router -->|"10 G"| enp7s0["enp7s0\nVLAN 70"]
    enp7s0 --> SW3["Unmanaged Switch or single host"]
    SW3 --> HomeOffice["Home-Office / Mgmt Network\nVLAN 70"]
```

The network runs on an iKoolCore R2 Max right now, which has two 10G ports and two 2.5G ports. We break this out into multiple pieces, where most things are sharing the 2.5G ports, except for my office, which has the remaining full 10G port (since the other one is used for the actual ISP connection to prevent bottlenecking).

The main machine is running NixOS, and this repo contains its configurations. Fun fact: This entire setup was done in a Meta Quest 3 VR headset (yes, even building the USB Boot Stick!), hence why there's a security key for a Meta Quest 3 device. NixOS was chosen specifically for its ability to be done entirely in code, which allows for LLMs to write the majority of the configurations for me. This is why the ARCH.md file is critical to be accurate, so that the LLM can know exactly what is needed when building.
