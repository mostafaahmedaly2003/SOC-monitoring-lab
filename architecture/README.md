# Architecture — Component Interaction & Data Flow

## 1. System Overview

The SOC lab connects six independent components into a single detection and response pipeline. Each component has one clear job. Together they cover the full lifecycle: **generate traffic → detect → correlate → automate → respond**.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SOC LAB ARCHITECTURE                             │
├──────────────┬──────────────┬──────────────┬──────────────┬────────────┤
│   GENERATE   │    DETECT    │  CORRELATE   │   AUTOMATE   │  RESPOND   │
├──────────────┼──────────────┼──────────────┼──────────────┼────────────┤
│ Kali Linux   │ Snort 3      │ Wazuh SIEM   │ Shuffle SOAR │ SendGrid   │
│ (attacker)   │ (IDS/IPS)    │ (manager +   │ (workflow    │ Email      │
│              │              │  indexer +   │  engine)     │            │
│ Windows 10   │ Wazuh Agent  │  dashboard)  │              │ Wazuh      │
│ (victim)     │ (all hosts)  │              │ VirusTotal   │ Active     │
│              │              │              │ API (enrich) │ Response   │
│ T-Pot        │ Sysmon       │              │              │ IP Block   │
│ (honeypot)   │ (Windows)    │              │              │            │
└──────────────┴──────────────┴──────────────┴──────────────┴────────────┘
```

---

## 2. Component Details

### 2.1 Kali Linux — Gateway + Attacker + Docker Host

Kali serves three roles simultaneously:

- **Attacker**: generates malicious traffic (Nmap, Hydra, Nikto, custom scripts)
- **Gateway**: routes traffic between network segments via three NICs
- **Docker host**: runs Snort as a systemd service; hosts Shuffle SOAR in Docker

**Why Kali as gateway?**
Placing Kali between the attacker segment and the victim forces all traffic through Snort. This mirrors real-world perimeter IPS placement where an inline device sits between untrusted and trusted networks.

### 2.2 Snort 3 — Dual-Mode IDS/IPS

Snort runs a single process on `eth2` in two modes at once:

| Mode | Mechanism | Behavior |
|---|---|---|
| **IPS** (inline) | iptables NFQUEUE | Intercepts packets, inspects, drops or passes |
| **IDS** (passive) | Alert output plugin | Writes matching events to `alert_fast.txt` |

Running IPS inline means IDS capability is automatic — every NFQUEUE-inspected packet that matches a rule triggers both the block action AND the log entry. You get both from one process.

### 2.3 Wazuh SIEM — Manager + Indexer + Dashboard

Wazuh is the central nervous system. It:

1. Receives log events from all three Wazuh agents (Kali, Windows, T-Pot)
2. Decodes raw log format into structured fields
3. Applies correlation rules to generate alerts
4. Stores everything in the OpenSearch index
5. Fires webhooks to Shuffle when alert level ≥ 10

**Wazuh components:**

| Component | Role | Port |
|---|---|---|
| Manager (wazuh-manager) | Agent enrollment, log analysis, rule matching | 1514, 1515 |
| Indexer (OpenSearch) | Alert storage and search | 9200 |
| Dashboard (Kibana-based) | Web UI for alerts and agents | 443 |
| REST API | Used by Shuffle for active response | 55000 |

### 2.4 Wazuh Agents — Log Collection on Each Host

Three agents run on three different hosts:

| Agent | Host | Collects |
|---|---|---|
| `kali-snort-agent` | Kali Linux | Snort `alert_fast.txt` via `snort-fast` log format |
| `windows-victim` | Windows 10 | Security, Sysmon, System, PowerShell event channels |
| `tpot-honeypot` | T-Pot VM | `/data/cowrie/log/cowrie.json` + `/data/elk/logstash/attack.log` |

Each agent:
- Enrolls once on port 1515 (gets unique ID + encryption key)
- Sends events continuously on port 1514 (TCP, AES encrypted)
- Appears as Active/Disconnected/Never connected in the dashboard

### 2.5 Sysmon — Enhanced Windows Visibility

Windows Event Logs alone miss most interesting activity. Sysmon adds:

| Event ID | What it captures |
|---|---|
| 1 | Process creation (command line, hash, parent process) |
| 3 | Network connections (src/dst IP, port, process name) |
| 7 | Image/DLL load |
| 10 | Process access (credential dumping attempts) |
| 11 | File creation |
| 13 | Registry value set |
| 22 | DNS query |

Wazuh has built-in decoders for all Sysmon event IDs.

### 2.6 T-Pot — Honeypot Intelligence

T-Pot runs ~20 honeypot services in Docker containers, each emulating a vulnerable service. Any connection to T-Pot is inherently suspicious (no legitimate users). This gives high-confidence IOCs.

Key honeypots in HIVE edition:

| Honeypot | Simulates | Port(s) |
|---|---|---|
| Cowrie | SSH / Telnet brute force | 22, 23 |
| Dionaea | Malware capture (SMB, FTP, HTTP) | 445, 21, 80 |
| Honeytrap | Generic TCP listener | Various |
| Mailoney | SMTP honeypot | 25 |
| Rdpy | RDP honeypot | 3389 |

T-Pot's Wazuh agent ships honeypot JSON to the central SIEM via a custom decoder.

### 2.7 Shuffle SOAR — Automated Response

Shuffle executes a visual workflow when triggered by a Wazuh webhook:

1. Receives the alert JSON (attacker IP, rule, severity, timestamp)
2. Extracts `srcip` field using regex
3. Queries VirusTotal API for IP reputation
4. If malicious: sends SendGrid email + triggers Wazuh active response (IP block)
5. If clean: logs the result as informational

**Why this matters:** The entire process takes < 15 seconds. A manual analyst workflow (check alert → look up IP → decide → block) takes minutes or hours.

---

## 3. Communication Map

```
                     TCP 1514/1515
kali-snort-agent ──────────────────────────────►
                                                  Wazuh Manager
windows-victim   ──────────────────────────────►  192.168.1.33
                     TCP 1514/1515                     │
tpot-honeypot    ──────────────────────────────►       │
                                                       │ Webhook POST
                                                       │ (level ≥ 10)
                                                       ▼
                                               Shuffle SOAR
                                               10.94.117.58:3443
                                                       │
                                          ┌────────────┴────────────┐
                                          │                         │
                                  VirusTotal API             SendGrid API
                                  (HTTPS GET)                (HTTPS POST)
                                          │                         │
                                  IP reputation              Email alert
                                  score returned             delivered
```

---

## 4. Alert Pipeline (step by step)

```
1. Kali runs: nmap -sS --max-rate 200 192.168.1.32
                    │
2. eth2 traffic intercepted by iptables NFQUEUE rule 0
                    │
3. Snort reads packet from NFQUEUE
   → Matches rule 1000002 (SYN scan threshold)
   → IPS verdict: ACCEPT (below threshold) or DROP (above threshold)
   → IDS: writes to /var/log/snort/alert_fast.txt
                    │
4. Wazuh agent (Kali) reads new line from alert_fast.txt
   → Encodes as event, sends to manager:1514
                    │
5. Wazuh Manager receives event
   → Decoder: snort (built-in)
   → Rule match: group "ids,snort" level 8
   → Stores in OpenSearch index
                    │
6. If level ≥ 10:
   → Integration module fires POST to Shuffle webhook
   → Payload: { "srcip": "...", "rule": {...}, "agent": {...} }
                    │
7. Shuffle workflow executes:
   → Extract srcip → VirusTotal GET → check malicious score
   → Branch: malicious → SendGrid email + active response IP block
   → Branch: clean → log as informational
```

---

## 5. Detection Pipeline Summary

| Source | Format | Wazuh Decoder | Rule Group | Alert Level |
|---|---|---|---|---|
| Snort alerts | `snort-fast` | Built-in `snort` | `ids,snort` | 6–10 |
| Windows Security | `eventchannel` | Built-in `windows` | `windows,authentication` | 5–12 |
| Windows Sysmon | `eventchannel` | Built-in `sysmon` | `sysmon` | 3–12 |
| T-Pot hits | `json` | Custom `tpot-json` | `honeypot,attack` | 10–12 |

**Levels explained:**
- 0–6: informational
- 7–9: low/medium severity (logged, not auto-responded)
- 10–11: high severity (triggers Shuffle webhook)
- 12+: critical (triggers Shuffle + immediate IP block)
