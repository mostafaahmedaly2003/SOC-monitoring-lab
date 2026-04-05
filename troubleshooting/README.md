# Troubleshooting Guide

Quick reference for the most common issues in this lab.

---

## Snort

### Problem: `DAQ failed to initialize: nfq`

**Cause:** iptables NFQUEUE rules not loaded before starting Snort.

**Fix:**
```bash
sudo modprobe nfnetlink_queue
sudo iptables -I FORWARD -j NFQUEUE --queue-num 0
sudo iptables -I INPUT  -i eth2 -j NFQUEUE --queue-num 0
sudo iptables -I OUTPUT -o eth2 -j NFQUEUE --queue-num 0
sudo systemctl restart snort-ips
```

---

### Problem: No alerts in `alert_fast.txt`

**Cause 1:** Snort is monitoring the wrong interface.
```bash
ip addr show   # confirm eth2 = 10.94.117.59
```

**Cause 2:** Rule syntax error silently failed at startup.
```bash
sudo snort -c /etc/snort/snort.lua --warn-all-rules 2>&1 | grep -i error
```

**Cause 3:** `snort_defaults.lua` not found at include path.
```bash
ls /etc/snort/snort_defaults.lua
# If missing:
sudo ln -s /usr/share/snort/lua/snort_defaults.lua /etc/snort/snort_defaults.lua
```

---

### Problem: Snort service keeps restarting

```bash
sudo journalctl -u snort-ips -n 30 --no-pager
```
Look for the exact error on the last failed start.

---

## Wazuh Agent (Kali)

### Problem: `Unable to connect to 192.168.1.33:1514`

**Step 1:** Test port reachability:
```bash
nc -zv 192.168.1.33 1514
```

**Step 2:** Check Wazuh manager is running on the OVA:
```bash
ssh wazuh@192.168.1.33
sudo systemctl status wazuh-manager
```

**Step 3:** Check firewall on Wazuh OVA:
```bash
sudo ufw status
sudo iptables -L INPUT | grep 1514
```

---

### Problem: Agent shows `Never connected` in dashboard

The agent registered but never sent any events.

```bash
# On Kali — check ossec.log for clues
sudo tail -30 /var/ossec/logs/ossec.log

# Re-register if needed
sudo /var/ossec/bin/agent-auth -m 192.168.1.33 -A kali-snort-agent -p 1515
sudo systemctl restart wazuh-agent
```

---

### Problem: Snort alerts not appearing in Wazuh dashboard

**Step 1:** Confirm Snort is actually writing to the file:
```bash
tail -5 /var/log/snort/alert_fast.txt
```

**Step 2:** Confirm Wazuh agent is monitoring the right path:
```bash
sudo grep -A3 "snort-fast" /var/ossec/etc/ossec.conf
# Must show: <location>/var/log/snort/alert_fast.txt</location>
```

**Step 3:** Force a fresh alert and watch agent log:
```bash
ping -c 6 192.168.1.32
sudo tail -f /var/ossec/logs/ossec.log
# Should see: "New event from /var/log/snort/alert_fast.txt"
```

---

## Wazuh Agent (Windows)

### Problem: `WazuhSvc` fails to start

```powershell
# Check Windows Event Log for service errors
Get-EventLog -LogName System -Source "Service Control Manager" -Newest 10
```

Common fix — corrupt client.keys file:
```powershell
# Delete and re-register
Remove-Item "C:\Program Files (x86)\ossec-agent\client.keys"
cd "C:\Program Files (x86)\ossec-agent"
.\agent-auth.exe -m 192.168.1.33 -A windows-victim -p 1515
Start-Service WazuhSvc
```

---

### Problem: Windows agent cannot reach Wazuh manager

```powershell
Test-NetConnection -ComputerName 192.168.1.33 -Port 1514
# If TcpTestSucceeded: False — check Windows Firewall
```

Add firewall rule:
```powershell
New-NetFirewallRule -DisplayName "Wazuh Agent" -Direction Outbound `
  -RemoteAddress 192.168.1.33 -RemotePort 1514,1515 -Protocol TCP -Action Allow
```

---

## T-Pot

### Problem: SSH refused after T-Pot install

T-Pot moves real SSH to port 64295. Port 22 is now Cowrie.

```bash
ssh -p 64295 admin@192.168.1.34
```

---

### Problem: Wazuh agent stopped after T-Pot reboot

T-Pot's reboot sometimes disables the agent if `systemctl enable` was not run.

```bash
ssh -p 64295 admin@192.168.1.34
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent
```

---

### Problem: T-Pot containers not starting

```bash
ssh -p 64295 admin@192.168.1.34
sudo docker ps -a | grep -v "Up"   # show stopped containers
sudo systemctl status tpot          # check T-Pot systemd unit
sudo journalctl -u tpot -n 50       # view logs
```

Most common cause: insufficient RAM. T-Pot needs 8 GB minimum.

---

## Shuffle SOAR

### Problem: No executions appear after Wazuh alert

**Step 1:** Verify webhook URL in Wazuh `ossec.conf` is correct:
```bash
ssh wazuh@192.168.1.33
sudo grep hook_url /var/ossec/etc/ossec.conf
```

**Step 2:** Test webhook manually from Kali:
```bash
curl -sk -X POST \
  https://10.94.117.58:3443/api/v1/hooks/webhook_XXXXXXXX \
  -H "Content-Type: application/json" \
  -d '{"srcip":"1.2.3.4","rule":{"level":10},"agent":{"name":"test"}}'
```
Expected: `{}` response (Shuffle accepts it).

**Step 3:** Check Shuffle logs:
```bash
docker logs shuffle-backend 2>&1 | tail -20
```

---

### Problem: VirusTotal step returns 403

API key is wrong or has expired. Re-copy from https://www.virustotal.com → Profile → API Key.

---

### Problem: SendGrid step returns 403

Sender email is not verified. Go to SendGrid → Settings → Sender Authentication → verify your sender address.

---

## Quick Health Check

Run this from Kali to check all services at once:

```bash
echo "=== Snort ===" && sudo systemctl is-active snort-ips
echo "=== Wazuh Agent (Kali) ===" && sudo systemctl is-active wazuh-agent
echo "=== NFQUEUE rule ===" && sudo iptables -L FORWARD | grep -c NFQUEUE
echo "=== Snort log ===" && wc -l /var/log/snort/alert_fast.txt
echo "=== Manager agents ===" && ssh wazuh@192.168.1.33 'sudo /var/ossec/bin/agent_control -l 2>/dev/null | grep Active | wc -l'
```

All lines should return non-zero / `active` to confirm the pipeline is healthy.
