# Network Topology

## 1. Design Goals

The topology was designed with three goals:
1. **Realistic traffic segmentation** — attack traffic, clean traffic, and management traffic stay on separate segments
2. **Inline IPS placement** — Snort sits physically between attacker and victim, just like a real perimeter IPS
3. **Centralized monitoring** — all endpoints report to one Wazuh manager regardless of which segment they are on

---

## 2. Network Diagram

```
                        ┌─────────────┐
                        │   INTERNET  │
                        └──────┬──────┘
                               │
                    ┌──────────▼──────────┐
                    │      eth0 — NAT     │  192.168.61.128
                    │   (internet egress  │
                    │    for Kali only)   │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼────────────────────────────────┐
                    │              KALI LINUX                   │
                    │                                           │
                    │  eth2 ─ 10.94.117.59  (Custom/Bridged)   │
                    │  │                                        │
                    │  │  ┌──────────────────────────────────┐  │
                    │  └──► SNORT 3.12.1.0                   │  │
                    │     │  IPS: iptables NFQUEUE queue=0   │  │
                    │     │  IDS: /var/log/snort/alert_fast  │  │
                    │     └──────────────────────────────────┘  │
                    │                                           │
                    │  eth1 ─ 192.168.1.31  (Bridged LAN)      │
                    │                                           │
                    │  ┌────────────┐    ┌──────────────────┐  │
                    │  │Wazuh Agent │    │  Shuffle SOAR    │  │
                    │  │(reads logs)│    │  10.94.117.58    │  │
                    │  └────────────┘    │  port 3443       │  │
                    └──────────┬─────────┴──────────────────┴──┘
                               │
              192.168.1.0/24   │   (Bridged — shared physical LAN)
    ┌──────────────────────────┼────────────────────────────────┐
    │                          │                                │
┌───▼────────────┐   ┌─────────▼──────────┐   ┌───────────────▼──┐
│  Windows 10    │   │   Wazuh Server     │   │     T-Pot         │
│ 192.168.1.32   │   │   192.168.1.33     │   │  192.168.1.34     │
│                │   │                    │   │                   │
│ Wazuh Agent    │   │  VirtualBox OVA    │   │  VirtualBox       │
│ Sysmon v15     │   │  v4.14.4           │   │  Debian 12        │
│                │   │  Manager:1514/1515 │   │  HIVE edition     │
│ VMware Guest   │   │  Dashboard:443     │   │  SSH: port 64295  │
│                │   │  API:55000         │   │  UI: port 64297   │
│                │   │                    │   │  Wazuh Agent      │
└────────────────┘   └────────────────────┘   └───────────────────┘
```

---

## 3. Network Segments Explained

### Segment 1 — NAT (192.168.61.0/24)
- **Purpose:** Internet access for Kali only
- **Devices:** Kali eth0
- **Traffic:** Package downloads, Docker image pulls, VirusTotal/SendGrid API calls
- **Why isolated:** Internet traffic should not reach the victim or SIEM directly

### Segment 2 — Internal LAN (192.168.1.0/24)
- **Purpose:** All managed devices communicate here
- **Devices:** Kali eth1, Windows 10, Wazuh Server, T-Pot
- **Traffic:** Wazuh agent enrollment (1515), log forwarding (1514), dashboard access (443)
- **Why bridged:** All VMs need to reach the Wazuh manager at 192.168.1.33

### Segment 3 — Management/Inspection (10.94.117.0/24)
- **Purpose:** Snort inspection interface + Shuffle SOAR
- **Devices:** Kali eth2 (Snort), Shuffle Docker
- **Traffic:** Raw attack packets pass through here; Shuffle webhook calls
- **Why separate:** Keeps attack traffic isolated from the clean LAN

---

## 4. Traffic Flow (Detailed)

### Attack Path (Kali → Windows)

```
Kali (attacker) generates packet to 192.168.1.32
        │
        ▼
iptables on Kali:
  FORWARD chain → NFQUEUE num 0
  INPUT   chain (eth2) → NFQUEUE num 0
        │
        ▼
Snort receives packet from NFQUEUE queue 0
  → Runs ruleset against packet
  → IDS: if matches alert rule → log to alert_fast.txt
  → IPS: if matches drop rule → verdict = DROP (packet discarded)
  → IPS: if no match → verdict = ACCEPT
        │
        ▼
ACCEPT verdict: packet forwarded via eth1 → Windows 10
DROP verdict:   packet discarded, Windows never sees it
```

### Log Path (Snort → Wazuh Dashboard)

```
/var/log/snort/alert_fast.txt (new line appended)
        │
        ▼
Wazuh Agent (Kali) — inotify detects new line
  → Reads line: "[1:1000002:1] Nmap SYN Scan {TCP} ..."
  → Encodes as JSON event
  → Sends over TCP 1514 to 192.168.1.33
        │
        ▼
Wazuh Manager (192.168.1.33)
  → Decoder: snort (built-in)
  → Parses: srcip, dstip, protocol, rule_id, msg
  → Rule match: group snort, level 8
  → Stores in OpenSearch
  → If level ≥ 10: POST webhook to Shuffle
        │
        ▼
Wazuh Dashboard (https://192.168.1.33)
  → Alert visible under Security Events
  → Filter: agent.name = kali-snort-agent
```

### Honeypot Path (T-Pot → Wazuh)

```
Kali probes port 22 on T-Pot (192.168.1.34)
        │
        ▼
Cowrie container accepts connection (fake SSH shell)
  → Logs interaction to /data/cowrie/log/cowrie.json
  → JSON: { "type":"cowrie", "src_ip":"192.168.1.31", ... }
        │
        ▼
Wazuh Agent (T-Pot) reads cowrie.json
  → Sends event to manager:1514
        │
        ▼
Wazuh Manager
  → Custom decoder: tpot-json
  → Custom rule: 200002 level 12
  → Alert: "T-Pot: SSH brute force on Cowrie from 192.168.1.31"
  → Level 12 → triggers Shuffle webhook immediately
```

---

## 5. Port Reference

### Wazuh Manager (192.168.1.33)

| Port | Protocol | Direction | Purpose |
|---|---|---|---|
| 1514 | TCP | Agents → Manager | Event forwarding (ongoing) |
| 1515 | TCP | Agents → Manager | Agent enrollment (one-time) |
| 443 | TCP | Browser → Manager | Dashboard (HTTPS) |
| 55000 | TCP | Shuffle → Manager | REST API (active response) |
| 9200 | TCP | Internal | OpenSearch indexer |

### Shuffle SOAR (10.94.117.58)

| Port | Protocol | Direction | Purpose |
|---|---|---|---|
| 3443 | TCP | Wazuh → Shuffle | Webhook trigger (HTTPS) |
| 3443 | TCP | Browser → Shuffle | Web UI |

### T-Pot (192.168.1.34)

| Port | Protocol | Direction | Purpose |
|---|---|---|---|
| 22 | TCP | Any → T-Pot | Cowrie SSH honeypot |
| 23 | TCP | Any → T-Pot | Cowrie Telnet honeypot |
| 25 | TCP | Any → T-Pot | Mailoney SMTP honeypot |
| 80 | TCP | Any → T-Pot | Dionaea HTTP honeypot |
| 445 | TCP | Any → T-Pot | Dionaea SMB honeypot |
| 3389 | TCP | Any → T-Pot | Rdpy RDP honeypot |
| 64295 | TCP | Admin → T-Pot | Real SSH (admin access) |
| 64297 | TCP | Browser → T-Pot | T-Pot web dashboard |

> **Important:** After T-Pot is installed, always use port **64295** for SSH. Port 22 is taken by Cowrie.

---

## 6. Sensor Placement

```
INTERNET
   │
   │  ← No monitoring here (NAT, external)
   │
[Kali eth0 — NAT boundary]
   │
   │  ← Snort sits HERE (eth2)
   │     All attack traffic inspected inline
   │     IPS drops before reaching victim
   │     IDS logs everything suspicious
   │
[Snort NFQUEUE — Inspection Point]
   │
   │  ← Clean traffic only passes here
   │
[Kali eth1 — Internal LAN boundary]
   │
   ├── Windows 10 ← Sysmon + Wazuh agent (host-level)
   ├── Wazuh Server ← SIEM collection point
   └── T-Pot ← Honeypot (all traffic here is suspicious)
```

---

## 7. Why This Topology Works

| Property | Explanation |
|---|---|
| **Segmentation** | Attack traffic (eth2) never touches the LAN (eth1) without passing Snort |
| **Inline IPS** | Snort physically intercepts packets — it's not a tap/mirror, it's in-path |
| **Centralized SIEM** | One Wazuh manager receives all sources over the same 192.168.1.0/24 segment |
| **Honeypot isolation** | T-Pot sits on the LAN — any traffic to it from outside is naturally suspicious |
| **Management separation** | Shuffle lives on the 10.94.117.x segment, away from victim traffic |
| **Scalability** | More VMs can join 192.168.1.0/24 and enroll with the same Wazuh manager |
