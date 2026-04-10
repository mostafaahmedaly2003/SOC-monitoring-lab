# SOC Mini-Lab: Snort + Wazuh + T-Pot + Shuffle SOAR

![Wazuh](https://img.shields.io/badge/Wazuh-4.14.4-005571?style=flat)
![Snort](https://img.shields.io/badge/Snort-3.12.1-CC0000?style=flat)
![T--Pot](https://img.shields.io/badge/T--Pot-24.04-orange?style=flat)
![Shuffle](https://img.shields.io/badge/Shuffle_SOAR-Automated_Response-6A0DAD?style=flat)
![NIST CSF](https://img.shields.io/badge/Framework-NIST_CSF_2.0-0057A8?style=flat)
![License](https://img.shields.io/badge/License-GPL--2.0-blue?style=flat)
![Detection](https://img.shields.io/badge/Detection_Time-5--15s-brightgreen?style=flat)
![Scenarios](https://img.shields.io/badge/Test_Scenarios-6%2F6_Passed-brightgreen?style=flat)

> **A fully integrated open-source SOC built in a virtualized lab environment.**  
> Detects and automatically responds to real attacks in under 15 seconds.  
> Stack: Kali Linux · Snort IDS/IPS · Wazuh SIEM · Windows 10 + Sysmon · T-Pot Honeypot · Shuffle SOAR

---

<p align="center">
  <img src="screenshots/12-soc-dashboard.png" alt="SOC Dashboard" width="900"/>
</p>

<h1 align="center">SOC Mini-Lab — Integrated Security Operations Center</h1>

<p align="center">
  <strong>A fully integrated, open-source SOC built in a virtualized lab environment.</strong><br>
  Network IDS/IPS &bull; SIEM Log Collection &bull; Honeypot Deception &bull; Automated Incident Response
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Prototype%20Complete-brightgreen?style=for-the-badge" alt="Status"/>
  <img src="https://img.shields.io/badge/Snort-3.12.1.0-blue?style=for-the-badge&logo=snort" alt="Snort"/>
  <img src="https://img.shields.io/badge/Wazuh-4.14.4-orange?style=for-the-badge" alt="Wazuh"/>
  <img src="https://img.shields.io/badge/T--Pot-24.04-red?style=for-the-badge" alt="T-Pot"/>
  <img src="https://img.shields.io/badge/Shuffle-SOAR-purple?style=for-the-badge" alt="Shuffle"/>
  <img src="https://img.shields.io/badge/Framework-NIST%20CSF%202.0-yellow?style=for-the-badge" alt="NIST"/>
  <img src="https://img.shields.io/badge/License-GPL--2.0-lightgrey?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-VMware%20%2B%20VirtualBox-informational?style=flat-square" alt="Platform"/>
  <img src="https://img.shields.io/badge/Response%20Time-%3C15s-success?style=flat-square" alt="Response Time"/>
  <img src="https://img.shields.io/badge/Test%20Scenarios-6%2F6%20Passed-success?style=flat-square" alt="Tests"/>
  <img src="https://img.shields.io/badge/Agents-3%20Active-blue?style=flat-square" alt="Agents"/>
</p>

---

## Table of Contents

- [Highlights](#-highlights)
- [Architecture Overview](#-architecture-overview)
- [Network Topology](#-network-topology)
- [Tools Used](#-tools--technology-stack)
- [Detection Pipeline](#-detection-pipeline)
- [Automation Workflow](#-automation-workflow)
- [Performance Results](#-performance-results)
- [Installation](#-installation-guide)
- [Screenshots](#-screenshots--demo)
- [Project Structure](#-project-structure)
- [Future Improvements](#-future-roadmap)
- [References](#-references)

---

## Highlights

<table>
<tr>
<td width="25%" align="center">
<h3>5</h3>
<strong>Core Components</strong><br>
<sub>Wazuh &bull; Snort &bull; Shuffle &bull; T-Pot &bull; Sysmon</sub>
</td>
<td width="25%" align="center">
<h3>&lt;15s</h3>
<strong>Attack to Block</strong><br>
<sub>End-to-end automated response</sub>
</td>
<td width="25%" align="center">
<h3>3</h3>
<strong>Active Agents</strong><br>
<sub>Kali + Windows + T-Pot</sub>
</td>
<td width="25%" align="center">
<h3>6/6</h3>
<strong>Tests Passed</strong><br>
<sub>100% detection rate</sub>
</td>
</tr>
</table>

> **End-to-end detection time:** 5-15 seconds from attack to automated response — no manual intervention required.

---

## Architecture Overview

```mermaid
flowchart TB
    subgraph INTERNET["INTERNET"]
        NET[("WAN")]
    end

    subgraph KALI["KALI LINUX — Gateway + Attacker"]
        ETH0["eth0: NAT\n192.168.61.128"]
        SNORT["Snort 3.12.1.0\nIPS: NFQUEUE drop\nIDS: alert_fast.txt"]
        WAGENT1["Wazuh Agent"]
        SHUFFLE["Shuffle SOAR\n:3443"]
    end

    subgraph INTERNAL["INTERNAL LAN — 192.168.1.0/24"]
        WIN["Windows 10\n192.168.1.32\nWazuh Agent + Sysmon"]
        WAZUH["Wazuh Server\n192.168.1.33\nManager + Indexer + Dashboard"]
        TPOT["T-Pot Honeypot\n192.168.1.34\nWazuh Agent"]
    end

    subgraph EXTERNAL["EXTERNAL SERVICES"]
        VT["VirusTotal API"]
        SG["SendGrid Email"]
    end

    NET -->|NAT| ETH0
    ETH0 --> SNORT
    SNORT -->|"clean traffic"| WIN
    SNORT -->|"attack traffic"| TPOT
    SNORT -->|"alerts"| WAGENT1
    WAGENT1 -->|TCP 1514| WAZUH
    WIN -->|"events"| WAZUH
    TPOT -->|"honeypot logs"| WAZUH
    WAZUH -->|"webhook L10+"| SHUFFLE
    SHUFFLE --> VT
    SHUFFLE --> SG

    style KALI fill:#1a1a2e,stroke:#00ff41,color:#00ff41
    style INTERNAL fill:#0d1117,stroke:#58a6ff,color:#58a6ff
    style SNORT fill:#ff4444,stroke:#ff4444,color:#fff
    style WAZUH fill:#0066cc,stroke:#0066cc,color:#fff
    style TPOT fill:#ff8800,stroke:#ff8800,color:#fff
    style SHUFFLE fill:#9933ff,stroke:#9933ff,color:#fff
```

<details>
<summary><strong>View Architecture Dashboard Screenshot</strong></summary>
<br>
<img src="screenshots/14-architecture-flow.png" alt="Architecture Flow" width="900"/>
</details>

**Full architecture details:** [`architecture/README.md`](architecture/README.md)

---

## Network Topology

### IP Assignment

| Machine | Interface | IP Address | Network | Role |
|:--------|:----------|:-----------|:--------|:-----|
| Kali Linux | eth0 | `192.168.61.128` | NAT | Internet egress |
| Kali Linux | eth1 | `192.168.1.31` | Bridged | Internal LAN |
| Kali Linux | eth2 | `10.94.117.59` | Bridged | Snort inspection |
| Windows 10 | eth0 | `192.168.1.32` | Bridged | Victim + Wazuh agent |
| Wazuh Server | eth0 | `192.168.1.33` | Bridged | SIEM manager |
| T-Pot | eth0 | `192.168.1.34` | Bridged | Honeypot |
| Shuffle SOAR | Docker | `10.94.117.58:3443` | — | SOAR engine |

### Network Segments

| Segment | CIDR | Purpose |
|:--------|:-----|:--------|
| NAT | `192.168.61.0/24` | Internet access for Kali only |
| Internal LAN | `192.168.1.0/24` | All agents to Wazuh manager |
| Management | `10.94.117.0/24` | Snort interface + Shuffle |

### Traffic Flow

```mermaid
sequenceDiagram
    participant K as Kali (Attacker)
    participant S as Snort IPS/IDS
    participant W as Windows (Victim)
    participant T as T-Pot (Honeypot)
    participant M as Wazuh Manager
    participant SH as Shuffle SOAR
    participant VT as VirusTotal
    participant E as SendGrid Email

    K->>S: Attack traffic (eth2)
    S--xK: IPS: DROP malicious packets
    S->>W: Clean traffic forwarded (eth1)
    S->>M: IDS alerts via Wazuh agent
    W->>M: Endpoint events (Sysmon/Security)
    T->>M: Honeypot hits via Wazuh agent
    M->>SH: Level 10+ alert webhook
    SH->>VT: IP reputation lookup
    VT-->>SH: Malicious score
    SH->>E: Alert email notification
    SH->>M: IP block (active response)
```

<details>
<summary><strong>View Network Topology Dashboard</strong></summary>
<br>
<img src="screenshots/13-network-topology-dashboard.png" alt="Network Topology" width="900"/>
</details>

**Full topology details:** [`topology/README.md`](topology/README.md)

---

## Tools & Technology Stack

| Tool | Version | Purpose | License |
|:-----|:--------|:--------|:--------|
| Kali Linux | 2025.4 | Attacker + gateway + Docker host | GPL |
| Snort | 3.12.1.0 | Network IDS/IPS (NFQUEUE inline) | GPL-2.0 |
| Wazuh | 4.14.4 OVA | SIEM: Manager + Indexer + Dashboard | GPL-2.0 |
| Windows 10 | 10.0.17763 | Victim endpoint | Proprietary |
| Sysmon | v15 | Enhanced Windows event logging | Free |
| T-Pot | 24.04 HIVE | Multi-honeypot platform | Apache-2.0 |
| Shuffle SOAR | Latest | Automated incident response | GPL-3.0 |
| VirusTotal API | v3 | IP reputation lookups | Free tier |
| SendGrid | v3 API | Email notifications | Free tier |
| VMware Workstation | Pro | Kali + Windows virtualization | Proprietary |
| VirtualBox | Latest | Wazuh + T-Pot virtualization | GPL-2.0 |
| Docker | Latest | Shuffle containers | Apache-2.0 |
| iptables/NFQUEUE | Kernel | Inline packet routing to Snort | GPL |

### Feature Comparison

| Capability | Traditional SOC | This Lab |
|:-----------|:----------------|:---------|
| Detection method | Manual log review | Automated IDS/IPS + SIEM correlation |
| Response time | Minutes to hours | **< 15 seconds** |
| Threat intel | Manual IOC lookup | Automated VirusTotal enrichment |
| Alerting | Email on schedule | Real-time webhook + email |
| Honeypot integration | Separate system | Unified in SIEM pipeline |
| Incident response | Manual playbooks | SOAR-automated workflows |

<details>
<summary><strong>View Tools & Stack Dashboard</strong></summary>
<br>
<img src="screenshots/15-tools-stack.png" alt="Tools & Stack" width="900"/>
</details>

---

## Detection Pipeline

```mermaid
flowchart LR
    subgraph ATTACK["ATTACK"]
        A1["Nmap SYN Scan"]
        A2["Hydra SSH Brute"]
        A3["ICMP Sweep"]
        A4["Honeypot Probe"]
    end

    subgraph DETECT["DETECT"]
        D1["Snort IDS\nalert_fast.txt"]
        D2["Snort IPS\nNFQUEUE DROP"]
        D3["Sysmon\nWindows Events"]
        D4["T-Pot\nJSON Logs"]
    end

    subgraph CORRELATE["CORRELATE"]
        C1["Wazuh Manager\n192.168.1.33"]
    end

    subgraph RESPOND["RESPOND"]
        R1["Shuffle SOAR"]
        R2["VirusTotal API"]
        R3["SendGrid Email"]
        R4["IP Block"]
    end

    A1 --> D1 & D2
    A2 --> D1 & D2
    A3 --> D1 & D2
    A4 --> D4
    D1 --> C1
    D3 --> C1
    D4 --> C1
    C1 -->|"Level 10+"| R1
    R1 --> R2
    R2 --> R3
    R2 --> R4

    style ATTACK fill:#ff4444,stroke:#ff4444,color:#fff
    style DETECT fill:#ff8800,stroke:#ff8800,color:#fff
    style CORRELATE fill:#0066cc,stroke:#0066cc,color:#fff
    style RESPOND fill:#00cc44,stroke:#00cc44,color:#fff
```

### Custom Snort Rules

| SID | Type | Rule | Threshold |
|:----|:-----|:-----|:----------|
| 1000001 | IDS | ICMP Ping Sweep | 5 pings / 2 sec |
| 1000002 | IDS | Nmap SYN Port Scan | 20 SYN / 1 sec |
| 1000003 | IDS | SSH Brute Force | 5 attempts / 60 sec |
| 1000004 | IDS | HTTP Non-Standard Port (C2) | per packet |
| 1000005 | **IPS** | **Aggressive Port Scan** | **30 SYN / 5 sec** |
| 1000006 | IDS | RDP Brute Force | 5 attempts / 30 sec |
| 1000007 | **IPS** | **ICMP Flood** | **50 pings / 1 sec** |
| 1000008 | IDS | FTP Login Attempt | per packet |
| 1000009 | IDS | DNS Amplification | dsize > 512 |

**Detection rules, decoders, and rule IDs:** [`detection-pipeline/README.md`](detection-pipeline/README.md)

---

## Automation Workflow

### Shuffle SOAR — Alert Enrichment Pipeline

```mermaid
flowchart TD
    A["Wazuh Alert\nLevel >= 10"] -->|webhook| B["Shuffle\nWebhook Trigger"]
    B --> C["Extract src_ip\n(regex parse)"]
    C --> D["VirusTotal\nIP Lookup"]
    D --> E{"Malicious\nscore > 0?"}
    E -->|YES| F["SendGrid\nAlert Email"]
    E -->|YES| G["Wazuh\nIP Block"]
    E -->|NO| H["Log: Benign\n(INFO level)"]

    style A fill:#0066cc,stroke:#0066cc,color:#fff
    style E fill:#ff8800,stroke:#ff8800,color:#fff
    style F fill:#00cc44,stroke:#00cc44,color:#fff
    style G fill:#ff4444,stroke:#ff4444,color:#fff
    style H fill:#666,stroke:#666,color:#fff
```

**Trigger condition:** Wazuh alert level >= 10
**Average response time:** < 15 seconds from detection to email

**Full workflow documentation:** [`automation-workflows/shuffle-lab1.md`](automation-workflows/shuffle-lab1.md)

---

## Performance Results

| Metric | Result | Rating |
|:-------|:-------|:-------|
| Snort to Wazuh latency | 1-3 seconds | Excellent |
| Wazuh to Shuffle latency | 2-5 seconds | Good |
| End-to-end (attack to block) | **5-15 seconds** | Excellent |
| VirusTotal API response | 1-3 seconds | Free Tier |
| T-Pot capture rate | 100% | Excellent |
| Email delivery (SendGrid) | 3-10 seconds | Good |
| Dashboard query time | 1-2 seconds | Good |

### Validated Attack Scenarios

| # | Attack | Tool | IPS Response | IDS Alert | SOAR Action | Status |
|:--|:-------|:-----|:-------------|:----------|:------------|:-------|
| 1 | Port scan | `nmap -sS` | Blocked after 30 SYN/5s | Rule 1000002 | Email sent | PASS |
| 2 | SSH brute force | `hydra` | Blocked after 5 attempts | Rule 1000003 | IP blocked | PASS |
| 3 | ICMP sweep | `ping -c` | Blocked after 50/s | Rule 1000001 | Logged | PASS |
| 4 | Malicious IP probe | `curl` | N/A | Wazuh alert | VT score > 0 - email | PASS |
| 5 | Honeypot SSH | `ssh` to T-Pot | N/A | Rule 200002 | Dashboard alert | PASS |
| 6 | FIM change | File edit on Win | N/A | Sysmon EID 1 | Dashboard alert | PASS |

<details>
<summary><strong>View Results & Performance Dashboard</strong></summary>
<br>
<img src="screenshots/16-results-metrics.png" alt="Results & Metrics" width="900"/>
</details>

---

## Installation Guide

Follow these guides in order:

| Step | Guide | Time |
|:-----|:------|:-----|
| 0 | [External Accounts Setup](installation/00-accounts-setup.md) | 15 min |
| 1 | [Kali Environment Setup](installation/01-kali-setup.md) | 20 min |
| 2 | [Snort IDS/IPS Configuration](installation/02-snort-ids-ips.md) | 30 min |
| 3 | [Wazuh Agent on Kali](installation/03-wazuh-agent-kali.md) | 20 min |
| 4 | [Windows Agent + Sysmon](installation/04-windows-agent-sysmon.md) | 25 min |
| 5 | [T-Pot Honeypot](installation/05-tpot-honeypot.md) | 60 min |
| 6 | [Shuffle SOAR Workflow](installation/06-shuffle-soar.md) | 30 min |
| 7 | [End-to-End Verification](installation/07-verification.md) | 15 min |

### Prerequisites

- VMware Workstation Pro (any recent version)
- VirtualBox (latest)
- Kali Linux VM with 3 network adapters configured
- Minimum **16 GB RAM** on host machine (8 GB for T-Pot alone)

---

## Screenshots & Demo

<!-- GIF placeholder: Replace with your own demo recording -->
<!--
<p align="center">
  <img src="screenshots/demo.gif" alt="SOC Lab Demo" width="800"/>
  <br>
  <em>Full attack-to-response pipeline in action</em>
</p>
-->

### SOC Dashboard Overview
<img src="screenshots/12-soc-dashboard.png" alt="SOC Dashboard" width="900"/>

### Network Topology
<img src="screenshots/13-network-topology-dashboard.png" alt="Network Topology" width="900"/>

### Architecture & Traffic Flow
<img src="screenshots/14-architecture-flow.png" alt="Architecture" width="900"/>

### Tools & Technology Stack
<img src="screenshots/15-tools-stack.png" alt="Tools & Stack" width="900"/>

### Results & Performance Metrics
<img src="screenshots/16-results-metrics.png" alt="Results & Metrics" width="900"/>

### Challenges & Solutions
<img src="screenshots/17-challenges-solutions.png" alt="Challenges" width="900"/>

### Future Roadmap
<img src="screenshots/18-future-roadmap.png" alt="Future Roadmap" width="900"/>

> **Need more screenshots?** See [`screenshots/README.md`](screenshots/README.md) for the full capture guide (15 required shots).

---

## Project Structure

```
SOC-Lab/
|
|-- README.md                          # You are here
|-- architecture/
|   +-- README.md                      # Component interaction + data flow
|-- topology/
|   +-- README.md                      # Network design + traffic flow
|-- installation/
|   |-- 00-accounts-setup.md           # VirusTotal + SendGrid accounts
|   |-- 01-kali-setup.md              # Kali network configuration
|   |-- 02-snort-ids-ips.md           # Snort full setup guide
|   |-- 03-wazuh-agent-kali.md        # Wazuh agent on Kali
|   |-- 04-windows-agent-sysmon.md    # Windows agent + Sysmon
|   |-- 05-tpot-honeypot.md           # T-Pot install guide
|   |-- 06-shuffle-soar.md            # Shuffle workflow build
|   +-- 07-verification.md            # End-to-end test checklist
|-- configurations/
|   |-- snort.lua                      # Snort 3 main config
|   |-- local.rules                    # Custom IDS/IPS detection rules
|   |-- ossec-kali-agent.conf         # Wazuh agent config (Kali)
|   |-- ossec-windows-snippet.xml     # Windows agent localfile blocks
|   |-- tpot-decoder.xml              # Custom T-Pot Wazuh decoder
|   +-- tpot-rules.xml                # Custom T-Pot Wazuh rules
|-- detection-pipeline/
|   +-- README.md                      # Alert pipeline + rule reference
|-- automation-workflows/
|   +-- shuffle-lab1.md                # SOAR workflow documentation
|-- screenshots/
|   +-- README.md                      # Screenshot guide + placeholders
|-- scripts/
|   |-- setup-nfqueue.sh              # iptables NFQUEUE setup
|   +-- verify-lab.sh                  # Full lab health check
|-- troubleshooting/
|   +-- README.md                      # Common errors + fixes
+-- references/
    +-- README.md                      # All links + citations
```

---

## Future Roadmap

- [ ] **Distributed architecture** — separate Wazuh components onto dedicated VMs/cloud
- [ ] **MISP integration** — automated IOC feeds for proactive threat hunting
- [ ] **AI/UEBA** — behavior analytics for anomaly detection beyond signatures
- [ ] **CACAO v2.0 playbooks** — standardize Shuffle workflows
- [ ] **Expanded honeypots** — additional T-Pot instances (web, DB, OT/ICS)
- [ ] **Ticketing integration** — connect Shuffle to TheHive or Jira
- [ ] **Compliance dashboards** — map Wazuh to NIS 2, ISO 27001, IEC 62443
- [ ] **MITRE ATT&CK mapping** — tag detection rules with ATT&CK technique IDs
- [ ] **HA/clustering** — eliminate single point of failure
- [ ] **Automated rule feeds** — CI/CD for Snort + Wazuh rule deployment

<details>
<summary><strong>View Future Roadmap Dashboard</strong></summary>
<br>
<img src="screenshots/18-future-roadmap.png" alt="Future Roadmap" width="900"/>
</details>

---

## References

| Resource | URL |
|:---------|:----|
| Wazuh Documentation | https://documentation.wazuh.com |
| Snort 3 Documentation | https://docs.snort.org |
| Shuffle SOAR | https://shuffler.io/docs |
| T-Pot GitHub | https://github.com/telekom-security/tpotce |
| VirusTotal API v3 | https://developers.virustotal.com/reference |
| NIST CSF 2.0 | https://www.nist.gov/cyberframework |
| MITRE ATT&CK | https://attack.mitre.org |
| NIST SP 800-61 Rev. 3 | https://csrc.nist.gov/publications/detail/sp/800-61/rev-3/final |

Full references: [`references/README.md`](references/README.md)

---

<p align="center">
  <em>Built as a SOC prototype. Open-source tools, production-representative architecture.</em><br>
  <strong>Security Framework:</strong> <a href="https://www.nist.gov/cyberframework">NIST Cybersecurity Framework 2.0</a> — Detect, Respond, Recover
</p>
