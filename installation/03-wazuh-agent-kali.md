# Step 3 — Wazuh Agent on Kali (Snort Log Forwarding)

This agent reads Snort's alert log and forwards events to the Wazuh manager.

---

## Install Agent

```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
  sudo gpg --no-default-keyring \
           --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg \
           --import
sudo chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] \
  https://packages.wazuh.com/4.x/apt/ stable main" | \
  sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt-get update
sudo WAZUH_MANAGER="192.168.1.33" apt-get install wazuh-agent -y
```

Verify:
```bash
/var/ossec/bin/wazuh-agentd --version
```
Expected: `Wazuh v4.14.4`

---

## Configure Agent

```bash
sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak
sudo tee /var/ossec/etc/ossec.conf > /dev/null << 'EOF'
<ossec_config>
  <client>
    <server>
      <address>192.168.1.33</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
  </client>

  <!-- Snort alert log -->
  <localfile>
    <log_format>snort-fast</log_format>
    <location>/var/log/snort/alert_fast.txt</location>
  </localfile>

  <!-- Kali system logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
</ossec_config>
EOF
```

---

## Register Agent

```bash
sudo /var/ossec/bin/agent-auth \
  -m 192.168.1.33 \
  -A kali-snort-agent \
  -p 1515
```

Expected:
```
INFO: Connected to 192.168.1.33:1515
INFO: Registered with ID: 001
```

If connection refused:
```bash
nc -zv 192.168.1.33 1515
# If fails → check Wazuh manager is running on OVA
```

---

## Start Agent

```bash
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent
```

Expected: `Active: active (running)`

Check connection:
```bash
sudo tail -10 /var/ossec/logs/ossec.log
```
Expected: `INFO: Connected to the server (192.168.1.33:1514/tcp).`

---

## Verify in Dashboard

1. Open `https://192.168.1.33` in browser (accept cert warning)
2. Login: `wazuh-user` / `wazuh`
3. Go to **Security → Agents**
4. Expected: `kali-snort-agent` with green **Active** status

Then trigger a Snort alert:
```bash
ping -c 8 192.168.1.32
```

In the dashboard → **Security Events** → filter `agent.name: kali-snort-agent`
Expected: Snort alert events appear within 30 seconds.
