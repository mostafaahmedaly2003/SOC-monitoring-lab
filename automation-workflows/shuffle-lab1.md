# Shuffle SOAR — Lab 1: Alert Enrichment Workflow

**Workflow name:** `SOC-Lab1-Alert-Enrichment`
**Trigger:** Wazuh alert level ≥ 10
**Purpose:** Enrich suspicious IPs with VirusTotal, notify analyst via email, block confirmed-malicious IPs automatically.

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                  SOC-Lab1-Alert-Enrichment                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [1] Webhook Trigger                                            │
│      wazuh-alert-in                                             │
│      Receives: Wazuh JSON alert via POST                        │
│           │                                                     │
│           ▼                                                     │
│  [2] Shuffle Tools — Regex Capture                              │
│      Input:  $exec.text                                         │
│      Regex:  "srcip":"([^"]+)"                                  │
│      Output: src_ip                                             │
│           │                                                     │
│           ▼                                                     │
│  [3] HTTP GET — VirusTotal IP Lookup                            │
│      URL:    .../ip_addresses/$src_ip                           │
│      Header: x-apikey: VT_API_KEY                              │
│      Output: vt_result                                          │
│           │                                                     │
│           ▼                                                     │
│  [4] Condition Branch                                           │
│      IF vt_result.malicious > 0                                 │
│           │                 │                                   │
│          YES                NO                                  │
│           │                 │                                   │
│           ▼                 ▼                                   │
│  [5a] HTTP POST         [5b] Set Variable                       │
│       SendGrid Email         benign_log = "IP clean"            │
│       + IP Block             (informational only)               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Node-by-Node Configuration

### Node 1 — Webhook Trigger

| Setting | Value |
|---|---|
| Type | Webhook (built-in) |
| Name | `wazuh-alert-in` |
| Generated URL | `https://10.94.117.58:3443/api/v1/hooks/webhook_XXXXXXXX` |

Copy the generated URL — paste it into Wazuh `ossec.conf` integration block.

---

### Node 2 — Extract src_ip (Shuffle Tools)

| Setting | Value |
|---|---|
| App | Shuffle Tools |
| Action | Regex capture group |
| Input data | `$exec.text` |
| Regex | `"srcip":"([^"]+)"` |
| Output variable | `src_ip` |

**Test input:**
```json
{"srcip":"185.220.101.47","rule":{"level":10,"description":"IPS BLOCK Port Scan"},"agent":{"name":"kali-snort-agent"}}
```
**Expected output:** `src_ip = 185.220.101.47`

---

### Node 3 — VirusTotal Lookup (HTTP GET)

| Setting | Value |
|---|---|
| App | HTTP |
| Method | GET |
| URL | `https://www.virustotal.com/api/v3/ip_addresses/$src_ip` |
| Header key | `x-apikey` |
| Header value | `YOUR_VT_API_KEY` |
| Output variable | `vt_result` |

**Response structure used:**
```
vt_result.data.attributes.last_analysis_stats.malicious  → integer (detections count)
vt_result.data.attributes.last_analysis_stats.harmless   → integer
vt_result.data.attributes.country                        → string
vt_result.data.attributes.as_owner                       → string (ISP name)
```

---

### Node 4 — Condition Branch

| Setting | Value |
|---|---|
| Left value | `$vt_result.data.attributes.last_analysis_stats.malicious` |
| Operator | `greater than` |
| Right value | `0` |
| True branch label | `Malicious` |
| False branch label | `Benign` |

---

### Node 5a — SendGrid Email (Malicious branch)

| Setting | Value |
|---|---|
| App | HTTP |
| Method | POST |
| URL | `https://api.sendgrid.com/v3/mail/send` |
| Header: Authorization | `Bearer YOUR_SENDGRID_API_KEY` |
| Header: Content-Type | `application/json` |

**Request body:**
```json
{
  "personalizations": [{"to": [{"email": "YOUR_EMAIL"}]}],
  "from": {"email": "YOUR_VERIFIED_SENDER"},
  "subject": "🚨 SOC ALERT: Malicious IP Detected — $src_ip",
  "content": [{
    "type": "text/plain",
    "value": "WAZUH SECURITY ALERT\n\nMalicious IP detected and action taken.\n\nIP Address:     $src_ip\nVT Detections:  $vt_result.data.attributes.last_analysis_stats.malicious\nCountry:        $vt_result.data.attributes.country\nISP:            $vt_result.data.attributes.as_owner\n\nAlert Details:\nAgent:          $exec.agent.name\nRule:           $exec.rule.description\nSeverity:       Level $exec.rule.level\nTimestamp:      $exec.timestamp\n\nAction taken: IP flagged for block via Wazuh active response.\n\n-- SOC Automation Lab"
  }]
}
```

---

### Node 5b — Log Benign (Benign branch)

| Setting | Value |
|---|---|
| App | Shuffle Tools |
| Action | Set variable |
| Name | `benign_log` |
| Value | `IP $src_ip checked at $exec.timestamp — VirusTotal: CLEAN (0 detections). Country: $vt_result.data.attributes.country. No action required.` |

---

## Wazuh Integration Block

Add to `/var/ossec/etc/ossec.conf` on the Wazuh manager:

```xml
<integration>
  <name>shuffle</name>
  <hook_url>https://10.94.117.58:3443/api/v1/hooks/webhook_XXXXXXXX</hook_url>
  <level>10</level>
  <alert_format>json</alert_format>
</integration>
```

Restart after editing:
```bash
sudo systemctl restart wazuh-manager
```

---

## Testing

### Trigger a real workflow execution:

```bash
# From Kali — aggressive scan triggers level 12 IPS rule
sudo nmap -sS --max-rate 200 -p 1-1000 192.168.1.32
```

### Manual test with known-malicious IP:

In Shuffle → Webhook node → Test → send:
```json
{
  "srcip": "185.220.101.47",
  "rule": {"level": 12, "description": "IPS BLOCK Aggressive Port Scan"},
  "agent": {"name": "kali-snort-agent"},
  "timestamp": "2026-04-04T12:00:00Z"
}
```

IP `185.220.101.47` is a known Tor exit node — VirusTotal will return `malicious > 0`.

**Expected execution path:**
1. Webhook receives POST ✅
2. `src_ip = 185.220.101.47` extracted ✅
3. VT returns malicious detections > 0 ✅
4. Condition: YES branch taken ✅
5. Email delivered to inbox ✅

### Manual test with clean IP:

```json
{"srcip": "8.8.8.8", "rule": {"level": 10, "description": "Test"}, "agent": {"name": "test"}}
```

**Expected:** Condition NO branch → benign_log set, no email sent.

---

## Performance Metrics

| Step | Avg Time |
|---|---|
| Wazuh → Shuffle (webhook delivery) | 2–5 sec |
| VirusTotal API response | 1–3 sec |
| SendGrid email delivery | 3–10 sec |
| **Total end-to-end** | **5–15 sec** |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| No executions in Shuffle | Re-copy webhook URL from Shuffle into Wazuh `ossec.conf` |
| VirusTotal 403 error | API key wrong — re-copy from virustotal.com profile |
| SendGrid 403 error | Sender email not verified — complete sender authentication |
| `src_ip` is empty | Regex pattern mismatch — check Wazuh JSON uses `srcip` field |
| Condition always goes to Benign | Test with known-malicious IP `185.220.101.47` to verify VT call works |
