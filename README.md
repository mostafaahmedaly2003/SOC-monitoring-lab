# SOC Mini-Lab — Integrated Security Operations Center

> A fully integrated, open-source SOC built in a virtualized lab environment.
> Covers network intrusion detection/prevention, SIEM log collection, honeypot deception, and automated incident response.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Lab Objectives](#lab-objectives)
- [Architecture Overview](#architecture-overview)
- [Tools Used](#tools-used)
- [Network Topology](#network-topology)
- [Detection Pipeline](#detection-pipeline)
- [Automation Workflow](#automation-workflow)
- [Performance Results](#performance-results)
- [Installation Summary](#installation-summary)
- [Screenshots](#screenshots)
- [Future Improvements](#future-improvements)
- [References](#references)

---

## Project Overview

This project builds a complete Security Operations Center (SOC) prototype using open-source tools deployed in a virtualized VMware/VirtualBox environment. The goal is to demonstrate a full threat detection and automated response pipeline — from raw attack traffic hitting the network to an automated email notification landing in an analyst's inbox — without any manual intervention.

The architecture connects five core components:

| Component | Role |
|---|---|
| **Kali Linux** | Attacker simulator + network gateway (3 NICs) |
| **Snort 3** | Dual-mode IDS/IPS — inline blocking + passive detection |
| **Wazuh SIEM** | Centralized log collection, correlation, alerting |
| **Windows 10** | Victim endpoint with Wazuh agent + Sysmon |
| **T-Pot** | Multi-honeypot sandbox attracting attacker traffic |
| **Shuffle SOAR** | Automated incident response workflows |

**End-to-end detection time:** 5–15 seconds from attack to automated response.

---

## Lab Objectives

1. Deploy a multi-layered network topology with clear segmentation between attacker, gateway, victim, and monitoring zones
2. Implement Snort as both IDS (passive alert logging) and IPS (inline NFQUEUE blocking) on a single interface
3. Centralize log collection from three sources: Snort alerts, Windows endpoint telemetry, and T-Pot honeypot hits
4. Automate incident response: suspicious IP enrichment via VirusTotal, email notification via SendGrid, IP blocking via Wazuh active response
5. Deploy T-Pot to attract and capture attacker behavior as a third intelligence source
6. Validate the full detection-to-response pipeline end-to-end with simulated attacks

**Security Framework:** [NIST Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework) — Detect, Respond, Recover functions.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INTERNET                                    │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ NAT (eth0: 192.168.61.128)
                    ┌───────▼────────────────────────────┐
                    │           KALI LINUX               │
                    │                                    │
                    │  ┌──────────────────────────────┐  │
                    │  │     SNORT 3.12.1.0 (eth2)    │  │
                    │  │   IPS: NFQUEUE (drop bad)    │  │
                    │  │   IDS: alert_fast.txt (log)  │  │
                    │  └──────────────────────────────┘  │
                    │  ┌──────────┐  ┌───────────────┐  │
                    │  │  Wazuh   │  │    Shuffle     │  │
                    │  │  Agent   │  │  SOAR :3443    │  │
                    │  └──────────┘  └───────────────┘  │
                    └──────────┬─────────────────────────┘
                               │ 192.168.1.0/24 (Bridged LAN)
          ┌────────────────────┼──────────────────────┐
          │                    │                      │
 ┌────────▼──────┐   ┌─────────▼───────┐   ┌─────────▼──────┐
 │  Windows 10   │   │  Wazuh Server   │   │    T-Pot       │
 │ 192.168.1.32  │   │  192.168.1.33   │   │  192.168.1.34  │
 │  Wazuh Agent  │   │  v4.14.4 OVA    │   │ Wazuh Agent    │
 │  + Sysmon     │   │  VirtualBox     │   │ (VirtualBox)   │
 └───────────────┘   └────────┬────────┘   └────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Shuffle Webhook  │
                    │   VirusTotal API   │
                    │   SendGrid Email   │
                    └────────────────────┘
```

**Full architecture details:** [`architecture/README.md`](architecture/README.md)

---

## Tools Used

| Tool | Version | Purpose | License |
|---|---|---|---|
| Kali Linux | 2025.4 | Attacker + gateway + Docker host | GPL |
| Snort | 3.12.1.0 | Network IDS/IPS | GPL-2.0 |
| Wazuh | 4.14.4 OVA | SIEM: Manager + Indexer + Dashboard | GPL-2.0 |
| Windows 10 | 10.0.17763 | Victim endpoint | Proprietary |
| Sysmon | v15 | Enhanced Windows event logging | Free |
| T-Pot | 24.04 HIVE | Multi-honeypot platform | Apache-2.0 |
| Shuffle SOAR | Latest | Automated incident response | GPL-3.0 |
| VirusTotal API | v3 | IP reputation lookups | Free tier |
| SendGrid | v3 API | Email notifications | Free tier |
| VMware Workstation | Pro | Kali + Windows virtualization | Proprietary |
| VirtualBox | Latest | Wazuh + T-Pot virtualization | GPL-2.0 |
| Docker | Latest | Wazuh + Shuffle containers | Apache-2.0 |
| iptables/NFQUEUE | Kernel | Inline packet routing to Snort | GPL |

---

## Network Topology

### IP Assignment

| Machine | Interface | IP Address | Network Type | Role |
|---|---|---|---|---|
| Kali Linux | eth0 | 192.168.61.128 | NAT | Internet egress |
| Kali Linux | eth1 | 192.168.1.31 | Bridged | Internal LAN |
| Kali Linux | eth2 | 10.94.117.59 | Bridged | Snort inspection / mgmt |
| Windows 10 | eth0 | 192.168.1.32 | Bridged | Victim + Wazuh agent |
| Wazuh Server | eth0 | 192.168.1.33 | Bridged | SIEM manager |
| T-Pot | eth0 | 192.168.1.34 | Bridged | Honeypot |
| Shuffle SOAR | Docker on Kali | 10.94.117.58:3443 | — | SOAR engine |

### Network Segments

| Segment | CIDR | Purpose |
|---|---|---|
| NAT | 192.168.61.0/24 | Internet access for Kali only |
| Internal LAN | 192.168.1.0/24 | All agents → Wazuh manager |
| Management | 10.94.117.0/24 | Snort interface + Shuffle |

### Traffic Flow

```
Step 1  →  Kali generates attack traffic toward Windows (via eth2)
Step 2  →  Snort intercepts ALL eth2 traffic via iptables NFQUEUE
Step 3  →  IPS: malicious packets DROPPED before reaching victim
           IDS: all suspicious packets LOGGED to alert_fast.txt
Step 4  →  Clean traffic forwarded to Windows via eth1
Step 5  →  Wazuh Agent (Kali) reads alert_fast.txt → sends to Manager
Step 6  →  Wazuh Agent (Windows) sends endpoint events → Manager
Step 7  →  Wazuh Manager correlates both streams → generates alerts
Step 8  →  Level 10+ alerts → Shuffle webhook → VirusTotal lookup
Step 9  →  Malicious IP? → SendGrid email + Wazuh IP block response
Step 10 →  T-Pot captures honeypot hits → Wazuh Agent → Manager
```

**Full topology details:** [`topology/README.md`](topology/README.md)

---

## Detection Pipeline

```
ATTACK                    DETECT                   CORRELATE              RESPOND
  │                          │                         │                     │
Nmap / Hydra    →    Snort IDS/IPS         →    Wazuh Manager    →    Shuffle SOAR
SSH brute force      alert_fast.txt             192.168.1.33           Webhook trigger
Port scan            (Kali agent)                    +                      │
Ping sweep               +                    Windows events          VirusTotal API
                   Sysmon events              (Sysmon/Security)            │
                   (Windows agent)                 +                  Conditional
                         +                    T-Pot hits              branch
                   T-Pot JSON logs            (tpot agent)                 │
                   (T-Pot agent)                                  Email + IP block
```

**Detection rules, decoders, and rule IDs:** [`detection-pipeline/README.md`](detection-pipeline/README.md)

---

## Automation Workflow

**Shuffle SOAR — Lab 1: Alert Enrichment**

```
[Wazuh Alert] → [Webhook Trigger] → [Extract src_ip] → [VirusTotal Lookup]
                                                               │
                                                    ┌──────────▼──────────┐
                                                    │  malicious score > 0 │
                                                    └──────┬───────┬───────┘
                                                         YES      NO
                                                          │        │
                                              [SendGrid Email]  [Log: Benign]
                                              + [IP Block]
```

**Trigger condition:** Wazuh alert level ≥ 10
**Average response time:** < 15 seconds from detection to email

**Full workflow documentation:** [`automation-workflows/shuffle-lab1.md`](automation-workflows/shuffle-lab1.md)

---

## Performance Results

| Metric | Result | Notes |
|---|---|---|
| Snort → Wazuh latency | 1–3 seconds | Near real-time log forwarding |
| Wazuh → Shuffle latency | 2–5 seconds | Local Docker webhook |
| End-to-end (attack → block) | **5–15 seconds** | Far faster than manual response |
| VirusTotal API response | 1–3 seconds | Free tier (4 req/min) |
| T-Pot capture rate | 100% | All connections logged |
| Email delivery (SendGrid) | 3–10 seconds | Free tier SMTP relay |
| Dashboard query time | 1–2 seconds | Lab-scale OpenSearch |

### Validated Attack Scenarios

| Attack | Tool | IPS Response | IDS Alert | SOAR Action |
|---|---|---|---|---|
| Port scan | Nmap SYN | Blocked after 30 SYN/5s | ✅ Rule 1000002 | Email sent |
| SSH brute force | Hydra | Blocked after 5 attempts | ✅ Rule 1000003 | IP blocked |
| ICMP sweep | ping -c | Blocked after 50/s | ✅ Rule 1000001 | Logged |
| Malicious IP probe | curl | N/A | ✅ Wazuh alert | VT score > 0 → email |
| Clean IP | curl 8.8.8.8 | N/A | ✅ Logged | VT clean → benign log |
| Honeypot SSH | ssh to T-Pot | N/A | ✅ Rule 200002 | Alert in dashboard |
| FIM change | File edit on Win | N/A | ✅ Sysmon EID 1 | Alert in dashboard |

---

## Installation Summary

Follow these guides in order:

| Step | Guide | Estimated Time |
|---|---|---|
| 0 | [External Accounts Setup](installation/00-accounts-setup.md) | 15 min |
| 1 | [Kali Environment Setup](installation/01-kali-setup.md) | 20 min |
| 2 | [Snort IDS/IPS Configuration](installation/02-snort-ids-ips.md) | 30 min |
| 3 | [Wazuh Agent on Kali](installation/03-wazuh-agent-kali.md) | 20 min |
| 4 | [Windows Agent + Sysmon](installation/04-windows-agent-sysmon.md) | 25 min |
| 5 | [T-Pot Honeypot](installation/05-tpot-honeypot.md) | 60 min |
| 6 | [Shuffle SOAR Workflow](installation/06-shuffle-soar.md) | 30 min |
| 7 | [End-to-End Verification](installation/07-verification.md) | 15 min |

**Prerequisites:**
- VMware Workstation Pro (any recent version)
- VirtualBox (latest)
- Kali Linux VM with 3 network adapters configured
- Minimum 16 GB RAM on host machine (8 GB for T-Pot alone)

---

## Screenshots

> **Add your screenshots to the `screenshots/` folder** after the lab is running.
> See [`screenshots/README.md`](screenshots/README.md) for the full capture guide (15 required shots).

### SOC Dashboard
![SOC Dashboard](screenshots/12-soc-dashboard.png)

### Wazuh — All 3 Agents Active
![Wazuh Agents](screenshots/01-wazuh-agents-active.png)

### Live Snort Alerts
![Snort Alerts](screenshots/02-snort-alerts-live.png)

### Wazuh Security Events (all sources)
![Security Events](screenshots/03-wazuh-security-events.png)

### Shuffle Workflow — Execution Complete
![Shuffle Execution](screenshots/09-shuffle-execution-green.png)

### T-Pot Dashboard
![T-Pot](screenshots/06-tpot-dashboard.png)

### Alert Email Received
![Email Alert](screenshots/11-email-received.png)

---

### Network Topology Diagram
![Network Topology](screenshots/13-network-topology.png)

---

## Future Improvements

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

---

## References

| Resource | URL |
|---|---|
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

## Project Structure

```
SOC-Lab/
├── README.md                          ← You are here
├── architecture/
│   └── README.md                      ← Component interaction + data flow
├── topology/
│   └── README.md                      ← Network design + traffic flow
├── installation/
│   ├── 00-accounts-setup.md           ← VirusTotal + SendGrid accounts
│   ├── 01-kali-setup.md               ← Kali network configuration
│   ├── 02-snort-ids-ips.md            ← Snort full setup guide
│   ├── 03-wazuh-agent-kali.md         ← Wazuh agent on Kali
│   ├── 04-windows-agent-sysmon.md     ← Windows agent + Sysmon
│   ├── 05-tpot-honeypot.md            ← T-Pot install guide
│   ├── 06-shuffle-soar.md             ← Shuffle workflow build
│   └── 07-verification.md             ← End-to-end test checklist
├── configurations/
│   ├── snort.lua                      ← Snort 3 main config
│   ├── local.rules                    ← Custom IDS/IPS detection rules
│   ├── ossec-kali-agent.conf          ← Wazuh agent config (Kali)
│   ├── ossec-windows-snippet.xml      ← Windows agent localfile blocks
│   ├── tpot-decoder.xml               ← Custom T-Pot Wazuh decoder
│   └── tpot-rules.xml                 ← Custom T-Pot Wazuh rules
├── detection-pipeline/
│   └── README.md                      ← Alert pipeline + rule reference
├── automation-workflows/
│   └── shuffle-lab1.md                ← SOAR workflow documentation
├── screenshots/
│   └── README.md                      ← Screenshot guide + placeholders
├── scripts/
│   ├── setup-nfqueue.sh               ← iptables NFQUEUE setup
│   └── verify-lab.sh                  ← Full lab health check
├── troubleshooting/
│   └── README.md                      ← Common errors + fixes
└── references/
    └── README.md                      ← All links + citations
```

---

*Built as part of a SOC diploma program prototype. Open-source tools, production-representative architecture.*
