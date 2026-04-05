# Detection Pipeline

## Overview

The detection pipeline has three parallel streams that all feed into one Wazuh manager. Each stream has its own log format, decoder, and rule group.

```
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   STREAM 1      │   │   STREAM 2      │   │   STREAM 3      │
│   Snort IDS/IPS │   │   Windows       │   │   T-Pot         │
│   (Kali)        │   │   Endpoint      │   │   Honeypot      │
└────────┬────────┘   └────────┬────────┘   └────────┬────────┘
         │                     │                     │
         ▼                     ▼                     ▼
  alert_fast.txt       Event Channels           cowrie.json
  snort-fast format    eventchannel format       JSON format
         │                     │                     │
         ▼                     ▼                     ▼
  Decoder: snort       Decoder: windows/sysmon  Decoder: tpot-json
  Group: ids,snort     Group: sysmon,windows    Group: honeypot,tpot
         │                     │                     │
         └─────────────────────┴─────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Wazuh Manager     │
                    │   192.168.1.33      │
                    │   Alert correlation │
                    └──────────┬──────────┘
                               │
                    level ≥ 10 │
                               ▼
                    ┌──────────────────────┐
                    │   Shuffle Webhook    │
                    │   VirusTotal lookup  │
                    │   SendGrid email     │
                    └──────────────────────┘
```

---

## Stream 1 — Snort Alerts

**Source:** `/var/log/snort/alert_fast.txt` on Kali
**Agent:** `kali-snort-agent` (ID: 001)
**Log format:** `snort-fast`
**Wazuh decoder:** built-in `snort`

### Alert Format

```
04/04-12:00:01.123456 [**] [1:1000002:1] "IDS Nmap SYN Port Scan" [**]
[Classification: Attempted Information Leak] [Priority: 2]
{TCP} 192.168.1.31:54321 -> 192.168.1.32:80
```

### Rule Reference

| Rule SID | Name | Level | Action |
|---|---|---|---|
| 1000001 | IDS ICMP Ping Sweep | 8 | Alert |
| 1000002 | IDS Nmap SYN Port Scan | 8 | Alert |
| 1000003 | IDS SSH Brute Force | 10 | Alert + Shuffle |
| 1000004 | IDS HTTP Non-Standard Port | 7 | Alert |
| 1000005 | IPS BLOCK Port Scan | 12 | Drop + Alert + Shuffle |
| 1000006 | IDS RDP Brute Force | 10 | Alert + Shuffle |
| 1000007 | IPS BLOCK ICMP Flood | 10 | Drop + Alert + Shuffle |
| 1000008 | IDS FTP Login Attempt | 6 | Alert |
| 1000009 | IDS DNS Amplification | 7 | Alert |

### Decoded Fields in Wazuh

| Field | Example |
|---|---|
| `data.id` | `1:1000002:1` |
| `data.classification` | `Attempted Information Leak` |
| `data.srcip` | `192.168.1.31` |
| `data.dstip` | `192.168.1.32` |
| `data.protocol` | `TCP` |
| `rule.description` | `IDS Nmap SYN Port Scan` |

---

## Stream 2 — Windows Endpoint

**Source:** Windows Event Channels
**Agent:** `windows-victim` (ID: 002)
**Log format:** `eventchannel`
**Wazuh decoder:** built-in `windows` + `sysmon`

### Key Event IDs Monitored

| Channel | Event ID | Meaning | Wazuh Level |
|---|---|---|---|
| Security | 4624 | Successful logon | 3 |
| Security | 4625 | Failed logon | 5 |
| Security | 4648 | Logon with explicit credentials | 8 |
| Security | 4672 | Special privileges assigned | 8 |
| Security | 4688 | Process creation (legacy) | 3 |
| Security | 4720 | User account created | 8 |
| Sysmon | 1 | Process creation (with command line) | 5 |
| Sysmon | 3 | Network connection | 3 |
| Sysmon | 7 | Image/DLL loaded | 5 |
| Sysmon | 10 | Process access (credential dump) | 12 |
| Sysmon | 11 | File created | 3 |
| Sysmon | 13 | Registry value set | 5 |
| Sysmon | 22 | DNS query | 3 |
| PowerShell | 4104 | Script block logging | 8 |

### Attack Detection Examples

| Attack | Detected via | Wazuh Rule Group |
|---|---|---|
| Pass-the-Hash | Sysmon EID 10 (lsass access) | sysmon,credential_access |
| Lateral movement | Sysmon EID 3 (SMB conn) | sysmon,lateral_movement |
| Persistence via registry | Sysmon EID 13 | sysmon,persistence |
| PowerShell download cradle | PowerShell EID 4104 | powershell,execution |
| Account creation | Security EID 4720 | windows,adduser |

---

## Stream 3 — T-Pot Honeypot

**Source:** `/data/cowrie/log/cowrie.json` on T-Pot
**Agent:** `tpot-honeypot` (ID: 003)
**Log format:** `json`
**Wazuh decoder:** custom `tpot-json` (see `configurations/tpot-decoder.xml`)

### Rule Reference

| Rule ID | Honeypot | Level | MITRE ATT&CK |
|---|---|---|---|
| 200001 | Any | 10 | — |
| 200002 | Cowrie (SSH/Telnet) | 12 | T1110 (Brute Force) |
| 200003 | Dionaea (SMB/FTP) | 12 | T1190 (Exploit Public App) |
| 200004 | Honeytrap (generic) | 10 | T1046 (Port Scan) |
| 200005 | Multiple (coordinated) | 14 | T1046 + T1110 |

### Sample Cowrie JSON Event

```json
{
  "eventid": "cowrie.login.failed",
  "src_ip": "192.168.1.31",
  "src_port": 54321,
  "dst_ip": "192.168.1.34",
  "dst_port": 22,
  "username": "root",
  "password": "admin123",
  "type": "cowrie",
  "timestamp": "2026-04-04T12:00:00.000Z",
  "sensor": "tpot"
}
```

---

## Alert Severity Levels

| Level | Meaning | Auto-Response |
|---|---|---|
| 0–6 | Informational | None |
| 7–9 | Low–Medium | Logged to dashboard |
| 10–11 | High | Shuffle webhook fired |
| 12+ | Critical | Shuffle + immediate IP block |

---

## Testing the Pipeline

```bash
# Test Stream 1 — trigger Snort alert
ping -c 10 192.168.1.32
sudo nmap -sS -p 1-1000 192.168.1.32

# Test Stream 2 — trigger Sysmon event (on Windows)
# PowerShell: Start-Process cmd.exe -ArgumentList "/c whoami"

# Test Stream 3 — trigger T-Pot hit
ssh root@192.168.1.34  # Cowrie answers; type any password

# Verify all in Wazuh
ssh wazuh@192.168.1.33
sudo /var/ossec/bin/agent_control -l
# All 3 agents must show: Status: Active
```
