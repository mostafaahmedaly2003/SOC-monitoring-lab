# Step 1 — Kali Linux Environment Setup

Kali needs IP forwarding enabled and all three adapters confirmed before anything else is configured.

---

## Confirm Network Adapters

```bash
ip addr show
```

Expected output — three adapters with these IPs:

| Interface | IP | Type |
|---|---|---|
| eth0 | 192.168.61.128 | NAT — internet |
| eth1 | 192.168.1.31 | Bridged — internal LAN |
| eth2 | 10.94.117.59 | Bridged — Snort / management |

If an adapter has no IP, bring it up:
```bash
sudo ip link set eth2 up
sudo dhclient eth2
```

---

## Enable IP Forwarding

Kali must forward packets between eth2 (attack side) and eth1 (victim side):

```bash
# Enable now
sudo sysctl -w net.ipv4.ip_forward=1

# Make permanent across reboots
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Verify:
```bash
cat /proc/sys/net/ipv4/ip_forward
```
Expected: `1`

---

## Test Connectivity Between Segments

```bash
# Can Kali reach Wazuh manager?
ping -c 3 192.168.1.33

# Can Kali reach Windows victim?
ping -c 3 192.168.1.32

# Can Kali reach internet?
ping -c 3 8.8.8.8
```

All three should succeed. If any fail, check adapter IP assignment and VMware network settings.

---

## Verify Snort Is Installed

```bash
snort --version
which snort
```

Expected:
```
/usr/bin/snort
Version 3.12.1.0
```

If not installed:
```bash
sudo apt update && sudo apt install snort3 -y
```

---

## Create Snort Log Directory

```bash
sudo mkdir -p /var/log/snort
sudo chmod 755 /var/log/snort
```

---

## Verify Docker Is Running (for Shuffle)

```bash
docker ps
```

Expected: Shuffle containers listed (if already deployed). If Docker not installed:
```bash
sudo apt install docker.io docker-compose -y
sudo systemctl enable docker
sudo systemctl start docker
```

---

## Summary Checklist

```bash
cat /proc/sys/net/ipv4/ip_forward    # must be 1
ip addr show eth0 | grep inet        # 192.168.61.x
ip addr show eth1 | grep inet        # 192.168.1.31
ip addr show eth2 | grep inet        # 10.94.117.59
ping -c 1 192.168.1.33               # Wazuh reachable
ping -c 1 8.8.8.8                    # Internet reachable
snort --version                      # 3.12.1.0
```

All passing → proceed to Step 2 (Snort configuration).
