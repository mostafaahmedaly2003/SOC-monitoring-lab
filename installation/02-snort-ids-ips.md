# Step 2 — Snort IDS/IPS Configuration

Snort 3 is configured on `eth2` (10.94.117.59) in **IPS inline mode** using iptables NFQUEUE. This gives you both IPS (packet dropping) and IDS (alert logging) from a single process.

---

## Verify Installation

```bash
snort --version
```
Expected: `Version 3.12.1.0`

```bash
snort --list-daqs
```
Expected output must include `nfq`. If missing:
```bash
sudo apt install libdaq-modules snort3-extra
```

---

## Configure snort.lua

```bash
sudo cp /etc/snort/snort.lua /etc/snort/snort.lua.bak
sudo tee /etc/snort/snort.lua > /dev/null << 'EOF'
HOME_NET = '192.168.1.0/24,10.94.117.0/24,192.168.61.0/24'
EXTERNAL_NET = '!$HOME_NET'

include 'snort_defaults.lua'

stream = {}
stream_tcp = {}
stream_udp = {}
stream_icmp = {}
http_inspect = {}

alert_fast =
{
    file = true,
    packet = false,
    limit = 10,
}

ips =
{
    enable_builtin_rules = true,
    rules = [[ include /etc/snort/rules/local.rules ]],
}
EOF
```

Validate:
```bash
sudo snort -c /etc/snort/snort.lua --warn-all-rules 2>&1 | tail -3
```
Expected: `Snort successfully validated the configuration (with 0 errors).`

---

## Write Detection Rules

```bash
sudo mkdir -p /etc/snort/rules
sudo tee /etc/snort/rules/local.rules > /dev/null << 'EOF'
# IDS Rules
alert icmp any any -> $HOME_NET any (msg:"IDS ICMP Ping Sweep"; itype:8; threshold:type threshold,track by_src,count 5,seconds 2; sid:1000001; rev:1;)
alert tcp  any any -> $HOME_NET any (msg:"IDS Nmap SYN Scan"; flags:S; threshold:type threshold,track by_src,count 20,seconds 1; sid:1000002; rev:1;)
alert tcp  any any -> $HOME_NET 22  (msg:"IDS SSH Brute Force"; flags:S; threshold:type threshold,track by_src,count 5,seconds 60; sid:1000003; rev:1;)
alert tcp  any any -> $HOME_NET !80 (msg:"IDS HTTP Non-Standard Port"; content:"GET"; http_method; sid:1000004; rev:1;)
alert tcp  any any -> $HOME_NET 3389 (msg:"IDS RDP Brute Force"; flags:S; threshold:type threshold,track by_src,count 5,seconds 30; sid:1000006; rev:1;)

# IPS Rules (drop — active blocking)
drop tcp  any any -> $HOME_NET any (msg:"IPS BLOCK Port Scan"; flags:S; threshold:type threshold,track by_src,count 30,seconds 5; sid:1000005; rev:1;)
drop icmp any any -> $HOME_NET any (msg:"IPS BLOCK ICMP Flood"; itype:8; threshold:type threshold,track by_src,count 50,seconds 1; sid:1000007; rev:1;)
EOF
```

---

## Set Up iptables NFQUEUE

```bash
sudo modprobe nfnetlink_queue
sudo iptables -I FORWARD -j NFQUEUE --queue-num 0
sudo iptables -I INPUT  -i eth2 -j NFQUEUE --queue-num 0
sudo iptables -I OUTPUT -o eth2 -j NFQUEUE --queue-num 0

# Make persistent
sudo apt install iptables-persistent -y
sudo netfilter-persistent save
```

Verify:
```bash
sudo iptables -L FORWARD --line-numbers | head -3
```
Expected: first line shows `NFQUEUE all -- anywhere anywhere NFQUEUE num 0`

---

## Test Snort in Foreground

```bash
sudo snort \
  -c /etc/snort/snort.lua \
  -i eth2 \
  -Q --daq nfq --daq-var queue=0 \
  -l /var/log/snort/ \
  -A alert_fast \
  --warn-all-rules
```

From another terminal, trigger a test:
```bash
ping -c 10 192.168.1.32
```

Check alerts:
```bash
cat /var/log/snort/alert_fast.txt
```
Expected: `[1:1000001:1] "IDS ICMP Ping Sweep" {ICMP} ...`

Stop Snort with `Ctrl+C`.

---

## Create Systemd Service

```bash
sudo tee /etc/systemd/system/snort-ips.service > /dev/null << 'EOF'
[Unit]
Description=Snort 3 IPS/IDS on eth2
After=network.target

[Service]
Type=simple
ExecStartPre=/sbin/iptables -I FORWARD -j NFQUEUE --queue-num 0
ExecStartPre=/sbin/iptables -I INPUT  -i eth2 -j NFQUEUE --queue-num 0
ExecStartPre=/sbin/iptables -I OUTPUT -o eth2 -j NFQUEUE --queue-num 0
ExecStart=/usr/bin/snort \
    -c /etc/snort/snort.lua \
    -i eth2 \
    -Q --daq nfq --daq-var queue=0 \
    -l /var/log/snort/ \
    -A alert_fast \
    --warn-all-rules
ExecStopPost=/sbin/iptables -D FORWARD -j NFQUEUE --queue-num 0
ExecStopPost=/sbin/iptables -D INPUT  -i eth2 -j NFQUEUE --queue-num 0
ExecStopPost=/sbin/iptables -D OUTPUT -o eth2 -j NFQUEUE --queue-num 0
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable snort-ips
sudo systemctl start snort-ips
sudo systemctl status snort-ips
```

Expected: `Active: active (running)`

---

## Verification Checklist

```bash
# Service running?
sudo systemctl status snort-ips | grep Active

# NFQUEUE rules active?
sudo iptables -L FORWARD | grep NFQUEUE

# Alerts being written?
ping -c 6 192.168.1.32 && sleep 2 && tail -3 /var/log/snort/alert_fast.txt
```
