# Step 6 — Shuffle SOAR Workflow (Lab 1)

**Workflow name:** `SOC-Lab1-Alert-Enrichment`

**What it does:** Receives Wazuh alert → extracts attacker IP → queries VirusTotal → if malicious, sends email + blocks IP.

**Prerequisites:** VirusTotal API key + SendGrid API key from Step 0.

---

## Access Shuffle

Open: `https://10.94.117.58:3443` (accept cert warning)

First time: create admin account when prompted.

---

## Create Webhook Trigger

1. Click **New Workflow** → Name: `SOC-Lab1-Alert-Enrichment` → Done
2. In the workflow editor, click **Triggers** tab (left panel)
3. Drag **Webhook** onto the canvas
4. Click the webhook node → Name: `wazuh-alert-in` → Save
5. **Copy the generated URL** — format: `https://10.94.117.58:3443/api/v1/hooks/webhook_XXXXXXXX`

> Save this URL — you need it for the Wazuh integration in the next section.

---

## Add Parse Step (Extract src_ip)

1. Apps tab → search `Shuffle Tools` → drag onto canvas → connect from Webhook
2. Click Shuffle Tools node:
   - Action: **Regex capture group**
   - Input data: `$exec.text`
   - Regex: `"srcip":"([^"]+)"`
   - Output variable: `src_ip`
3. Save

Test: click Run with input `{"srcip":"1.2.3.4","rule":{"level":10}}` → Expected output: `src_ip = 1.2.3.4`

---

## Add VirusTotal Lookup

1. Apps → `HTTP` → drag → connect from Shuffle Tools
2. Click HTTP node:
   - Action: **GET**
   - URL: `https://www.virustotal.com/api/v3/ip_addresses/$src_ip`
   - Headers → Add:
     - Key: `x-apikey` / Value: `YOUR_VT_API_KEY`
   - Output variable: `vt_result`
3. Save

Test with known clean IP first: temporarily set URL to `.../ip_addresses/1.1.1.1` → Run → verify JSON response.

---

## Add Condition Branch

1. Triggers panel → drag **Condition** → connect from HTTP node
2. Configure:
   - Left: `$vt_result.data.attributes.last_analysis_stats.malicious`
   - Operator: `greater than`
   - Right: `0`
3. Label True branch: `Malicious` / False branch: `Benign`
4. Save

---

## Malicious Branch — SendGrid Email

1. Apps → HTTP → drag → connect from Condition **True** branch
2. Configure:
   - Action: **POST**
   - URL: `https://api.sendgrid.com/v3/mail/send`
   - Headers:
     - `Authorization`: `Bearer YOUR_SENDGRID_API_KEY`
     - `Content-Type`: `application/json`
   - Body:
   ```json
   {
     "personalizations": [{"to": [{"email": "YOUR_EMAIL"}]}],
     "from": {"email": "YOUR_VERIFIED_SENDER"},
     "subject": "SOC ALERT: Malicious IP — $src_ip",
     "content": [{
       "type": "text/plain",
       "value": "Wazuh detected a malicious IP.\n\nIP: $src_ip\nVT detections: $vt_result.data.attributes.last_analysis_stats.malicious\nAgent: $exec.agent.name\nRule: $exec.rule.description"
     }]
   }
   ```
3. Save

---

## Benign Branch — Log Info

1. Apps → Shuffle Tools → connect from Condition **False** branch
2. Action: **Set variable** → Name: `benign_log` → Value: `IP $src_ip checked — VT CLEAN. No action needed.`
3. Save

---

## Configure Wazuh to Send Alerts to Shuffle

SSH into Wazuh manager:
```bash
ssh wazuh@192.168.1.33
sudo nano /var/ossec/etc/ossec.conf
```

Add before `</ossec_config>`:
```xml
<integration>
  <name>shuffle</name>
  <hook_url>https://10.94.117.58:3443/api/v1/hooks/webhook_XXXXXXXX</hook_url>
  <level>10</level>
  <alert_format>json</alert_format>
</integration>
```

Replace `webhook_XXXXXXXX` with your actual Shuffle webhook URL.

```bash
sudo systemctl restart wazuh-manager
sudo systemctl status wazuh-manager
```

---

## Enable Workflow and Test

In Shuffle: toggle **Enable** (top right) → Save workflow.

Trigger a level 10+ alert from Kali:
```bash
sudo nmap -sS --max-rate 200 -p 1-1000 192.168.1.32
```

In Shuffle → workflow → **Executions** tab:
- New execution appears within 10–15 seconds
- Click it → all nodes should show green
- VirusTotal node shows response JSON
- Email received in inbox (if malicious) or benign log set (if clean)

Test with known-malicious IP (Shuffle → Webhook → Test):
```json
{
  "srcip": "185.220.101.47",
  "rule": {"level": 10, "description": "Test malicious IP"},
  "agent": {"name": "kali-snort-agent"},
  "timestamp": "2026-04-04T12:00:00Z"
}
```
Expected: VT returns malicious detections > 0 → email sent.
