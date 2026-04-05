# Screenshots Guide

This folder holds all visual evidence of the lab working. Screenshots make your GitHub repo professional and prove the setup actually runs.

---

## How to Take Screenshots

**Windows/Kali:** `Win + Shift + S` → crop select → paste into Paint → Save as PNG
**Phone:** Use screen recording or screenshot then transfer via USB/cloud

---

## Required Screenshots (in order)

### 1. `01-wazuh-agents-active.png`
**What to capture:** Wazuh Dashboard → Security → Agents
**What should be visible:** All 3 agents with green Active status:
- `kali-snort-agent`
- `windows-victim`
- `tpot-honeypot`

**URL:** `https://192.168.1.33` → Agents

---

### 2. `02-snort-alerts-live.png`
**What to capture:** Kali terminal running `tail -f /var/log/snort/alert_fast.txt` with alerts scrolling
**What should be visible:** Alert lines like:
```
[1:1000002:1] "IDS Nmap SYN Port Scan" {TCP} 192.168.1.31 -> 192.168.1.32
```

**Command:**
```bash
tail -f /var/log/snort/alert_fast.txt
# In another terminal: sudo nmap -sS 192.168.1.32
```

---

### 3. `03-wazuh-security-events.png`
**What to capture:** Wazuh Dashboard → Security Events → filtered by last 15 minutes
**What should be visible:** Events from all 3 agents (Snort, Sysmon, T-Pot)

**URL:** `https://192.168.1.33` → Security Events → set time range to Last 15 minutes

---

### 4. `04-wazuh-snort-alert-detail.png`
**What to capture:** Click on a single Snort alert in Security Events → expand the detail panel
**What should be visible:** Fields including `srcip`, `dstip`, `rule.description`, `agent.name: kali-snort-agent`

---

### 5. `05-sysmon-event-wazuh.png`
**What to capture:** Security Events filtered by `agent.name: windows-victim` and `data.win.system.channel: Sysmon/Operational`
**What should be visible:** Sysmon event with process name, command line, parent process

---

### 6. `06-tpot-dashboard.png`
**What to capture:** T-Pot web dashboard at `https://192.168.1.34:64297`
**What should be visible:** Kibana T-Pot overview with world map and attack counters

---

### 7. `07-tpot-alert-wazuh.png`
**What to capture:** Wazuh Security Events filtered by `agent.name: tpot-honeypot`
**What should be visible:** Rule 200002 alert — "T-Pot: SSH/Telnet brute force on Cowrie"

---

### 8. `08-shuffle-workflow.png`
**What to capture:** Shuffle workflow editor showing all 5 nodes connected
**What should be visible:** Webhook → Shuffle Tools → HTTP → Condition → SendGrid + Log Variable

**URL:** `https://10.94.117.58:3443`

---

### 9. `09-shuffle-execution-green.png`
**What to capture:** Shuffle → Executions tab → click a completed execution
**What should be visible:** All nodes green (success), VirusTotal response visible in HTTP node

---

### 10. `10-virustotal-response.png`
**What to capture:** Inside the Shuffle execution, click the VirusTotal (HTTP GET) node
**What should be visible:** JSON response with `last_analysis_stats.malicious > 0`

---

### 11. `11-email-received.png`
**What to capture:** Your email inbox showing the SOC alert email from SendGrid
**What should be visible:** Subject line with malicious IP, VT detection count, agent name

---

### 12. `12-soc-dashboard.png`
**What to capture:** `dashboard_v2.html` open in a browser (full page screenshot)
**What should be visible:** Dark SOC dashboard with Overview page, KPI cards, and status indicators

**How:** Double-click `dashboard_v2.html` → takes full screenshot with `Win + Shift + S`

---

### 13. `13-network-topology.png`
**What to capture:** `soc_revised_topology.svg` open in a browser
**What should be visible:** Full network diagram with all components and traffic flows

---

### 14. `14-snort-service-status.png`
**What to capture:** `sudo systemctl status snort-ips` output in terminal
**What should be visible:** `Active: active (running)` in green

---

### 15. `15-all-agents-terminal.png`
**What to capture:** Wazuh manager terminal output of `agent_control -l`
**What should be visible:**
```
ID: 001  Name: kali-snort-agent   Status: Active
ID: 002  Name: windows-victim     Status: Active
ID: 003  Name: tpot-honeypot      Status: Active
```

---

## Folder Structure

```
screenshots/
├── README.md                    ← this file
├── 01-wazuh-agents-active.png
├── 02-snort-alerts-live.png
├── 03-wazuh-security-events.png
├── 04-wazuh-snort-alert-detail.png
├── 05-sysmon-event-wazuh.png
├── 06-tpot-dashboard.png
├── 07-tpot-alert-wazuh.png
├── 08-shuffle-workflow.png
├── 09-shuffle-execution-green.png
├── 10-virustotal-response.png
├── 11-email-received.png
├── 12-soc-dashboard.png
├── 13-network-topology.png
├── 14-snort-service-status.png
└── 15-all-agents-terminal.png
```

---

## Tips

- Take screenshots **after** the full lab is running and all attacks have been simulated
- Use **full-screen** captures for dashboards — they look more professional
- For terminal screenshots, use a **dark theme** terminal (already default on Kali)
- Add screenshots to the main `README.md` by inserting:
  ```markdown
  ![Wazuh Agents Active](screenshots/01-wazuh-agents-active.png)
  ```
