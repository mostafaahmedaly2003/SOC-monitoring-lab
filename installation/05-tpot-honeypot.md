# Step 5 — T-Pot Honeypot

T-Pot 24.04 installs on a fresh Debian 12 VM and converts it into a multi-honeypot appliance.

**VM requirements:** 8 GB RAM, 128 GB disk, 4 CPU cores, 1 bridged NIC.

---

## Create Debian 12 VM (VirtualBox)

1. Download Debian 12 netinstall ISO: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
2. VirtualBox → New VM:
   - Name: `T-Pot`, Type: Linux, Version: Debian 64-bit
   - RAM: 8192 MB, CPU: 4, Disk: 128 GB (dynamic)
   - Network: Bridged Adapter → your physical NIC
3. Install Debian 12 minimal:
   - Hostname: `tpot`
   - Software: SSH server + standard utilities only (uncheck desktop)

---

## Set Static IP

Login as root after install:
```bash
nano /etc/network/interfaces
```

Replace eth0 section:
```
auto eth0
iface eth0 inet static
    address 192.168.1.34
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8
```

Apply:
```bash
systemctl restart networking
ip addr show eth0
```
Expected: `inet 192.168.1.34/24`

---

## Install Wazuh Agent FIRST (before T-Pot)

> **Critical:** Install the Wazuh agent before running the T-Pot installer.
> T-Pot restructures the system and can interfere with agent installation if done after.

```bash
apt-get install curl gnupg -y

curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
  gpg --no-default-keyring \
      --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg \
      --import
chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] \
  https://packages.wazuh.com/4.x/apt/ stable main" | \
  tee /etc/apt/sources.list.d/wazuh.list

apt-get update
WAZUH_MANAGER="192.168.1.33" apt-get install wazuh-agent -y
```

Configure agent:
```bash
tee /var/ossec/etc/ossec.conf > /dev/null << 'EOF'
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
  </client>

  <localfile>
    <log_format>json</log_format>
    <location>/data/cowrie/log/cowrie.json</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
</ossec_config>
EOF
```

Register and start:
```bash
/var/ossec/bin/agent-auth -m 192.168.1.33 -A tpot-honeypot -p 1515
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

---

## Install T-Pot

```bash
apt-get install git -y
git clone https://github.com/telekom-security/tpotce
cd tpotce
./install.sh --type=user
```

During install:
- Select edition: **HIVE** (all honeypots)
- Set web UI password when prompted — save this

The installer pulls ~3 GB of Docker images. The VM reboots automatically. Wait 15–20 minutes.

---

## After Reboot

> Port 22 is now Cowrie (honeypot). Use port **64295** for SSH:

```bash
ssh -p 64295 admin@192.168.1.34
```

Verify containers:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}" | head -20
```
Expected: 10+ containers running including `cowrie`, `dionaea`, `honeytrap`

Access T-Pot dashboard (browser/phone):
`https://192.168.1.34:64297` → accept cert warning → login with your password

Verify Wazuh agent survived reboot:
```bash
systemctl status wazuh-agent
```
If stopped: `systemctl enable wazuh-agent && systemctl start wazuh-agent`

---

## Add Custom Decoder to Wazuh Manager

SSH into Wazuh OVA:
```bash
ssh wazuh@192.168.1.33
```

Create decoder:
```bash
sudo tee /var/ossec/etc/decoders/tpot_decoder.xml > /dev/null << 'EOF'
<decoder name="tpot-json">
  <prematch>{"type":</prematch>
</decoder>

<decoder name="tpot-json-fields">
  <parent>tpot-json</parent>
  <use_own_name>true</use_own_name>
  <json_null_field>discard</json_null_field>
  <regex>"src_ip":"(\.+)"</regex>
  <order>srcip</order>
</decoder>
EOF
```

Create rules:
```bash
sudo tee /var/ossec/etc/rules/tpot_rules.xml > /dev/null << 'EOF'
<group name="honeypot,tpot,attack">
  <rule id="200001" level="10">
    <decoded_as>tpot-json</decoded_as>
    <description>T-Pot: Honeypot hit recorded</description>
  </rule>

  <rule id="200002" level="12">
    <if_sid>200001</if_sid>
    <field name="type">cowrie</field>
    <description>T-Pot: SSH/Telnet brute force on Cowrie from $(srcip)</description>
    <group>honeypot,brute_force</group>
  </rule>

  <rule id="200003" level="12">
    <if_sid>200001</if_sid>
    <field name="type">dionaea</field>
    <description>T-Pot: Malware/exploit on Dionaea from $(srcip)</description>
    <group>honeypot,malware</group>
  </rule>
</group>
EOF

sudo systemctl restart wazuh-manager
```

---

## Test Honeypot Hit → Wazuh Alert

From Kali:
```bash
ssh root@192.168.1.34     # connects to Cowrie
# type any password, wait 5 seconds, Ctrl+C
```

Check on T-Pot:
```bash
ssh -p 64295 admin@192.168.1.34
sudo tail -3 /data/cowrie/log/cowrie.json
```
Expected: JSON with `"src_ip": "192.168.1.31"`

Check in Wazuh dashboard: filter `agent.name: tpot-honeypot` → rule ID 200002 alert visible.
