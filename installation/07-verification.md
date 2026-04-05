# Step 7 — End-to-End Verification

Run this checklist after all phases are complete. Every check must pass.

---

## Full Attack Simulation

### From Kali — trigger all 3 sources at once:

```bash
# 1. Snort IDS trigger (ICMP + SYN scan)
ping -c 10 192.168.1.32
sudo nmap -sS -p 1-1000 --max-rate 100 192.168.1.32

# 2. T-Pot honeypot trigger
timeout 5 ssh root@192.168.1.34 || true
sudo nmap -p 22,23,80,445,3389 192.168.1.34
```

### On Windows — trigger Sysmon events:
```powershell
Start-Process cmd.exe -ArgumentList "/c whoami && ipconfig"
Invoke-WebRequest -Uri "http://192.168.1.31" -UseBasicParsing -ErrorAction SilentlyContinue
```

---

## Verification Checklist

```bash
# ── ON KALI ──────────────────────────────────────────────

# Snort running in IPS mode?
sudo systemctl status snort-ips | grep Active
# Expected: active (running)

# NFQUEUE rules active?
sudo iptables -L FORWARD | grep NFQUEUE
# Expected: NFQUEUE all -- anywhere anywhere NFQUEUE num 0

# Snort writing alerts?
tail -5 /var/log/snort/alert_fast.txt
# Expected: recent alert lines

# Wazuh agent running?
sudo systemctl status wazuh-agent | grep Active
# Expected: active (running)

# Agent connected to manager?
sudo tail -3 /var/ossec/logs/ossec.log
# Expected: Connected to the server (192.168.1.33:1514/tcp)
```

```bash
# ── ON WAZUH MANAGER (ssh wazuh@192.168.1.33) ────────────

# All 3 agents active?
sudo /var/ossec/bin/agent_control -l
# Expected:
# ID: 001  Name: kali-snort-agent   Status: Active
# ID: 002  Name: windows-victim     Status: Active
# ID: 003  Name: tpot-honeypot      Status: Active

# Shuffle integration loaded?
sudo grep -c "shuffle" /var/ossec/etc/ossec.conf
# Expected: 1 or more
```

```powershell
# ── ON WINDOWS VM ─────────────────────────────────────────

# Wazuh agent running?
(Get-Service WazuhSvc).Status
# Expected: Running

# Sysmon running?
(Get-Service Sysmon64).Status
# Expected: Running
```

```bash
# ── ON T-POT (ssh -p 64295 admin@192.168.1.34) ────────────

# Wazuh agent running?
sudo systemctl status wazuh-agent | grep Active
# Expected: active (running)

# Honeypot containers up?
docker ps | grep -c "Up"
# Expected: 10 or more
```

---

## Dashboard Checks (browser or phone)

| URL | What to check | Expected |
|---|---|---|
| `https://192.168.1.33` | Agents page | 3 green Active agents |
| `https://192.168.1.33` | Security Events (last 15 min) | Snort + Sysmon + T-Pot alerts |
| `https://192.168.1.34:64297` | T-Pot dashboard | Loads, honeypot counters updating |
| `https://10.94.117.58:3443` | Shuffle workflow | Enabled, recent execution visible |

---

## All 12 Checks Passing = Lab Complete ✓

| # | Check | Status |
|---|---|---|
| 1 | `snort-ips` service active | ☐ |
| 2 | NFQUEUE iptables rule present | ☐ |
| 3 | Snort alerts written to file | ☐ |
| 4 | Wazuh agent (Kali) active | ☐ |
| 5 | All 3 agents Active in manager | ☐ |
| 6 | Shuffle integration configured | ☐ |
| 7 | WazuhSvc running on Windows | ☐ |
| 8 | Sysmon running on Windows | ☐ |
| 9 | Wazuh agent (T-Pot) active | ☐ |
| 10 | T-Pot containers running (10+) | ☐ |
| 11 | 3 agents green in dashboard | ☐ |
| 12 | Shuffle workflow executed successfully | ☐ |
