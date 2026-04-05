#!/bin/bash
# =============================================================
# verify-lab.sh — Full SOC Lab Health Check
# Run from Kali Linux
# Checks all services, agents, and pipeline components
# =============================================================

WAZUH_IP="192.168.1.33"
TPOT_IP="192.168.1.34"
WINDOWS_IP="192.168.1.32"
SHUFFLE_IP="10.94.117.58"
SHUFFLE_PORT="3443"
PASS=0
FAIL=0

check() {
    local desc="$1"
    local cmd="$2"
    local expected="$3"
    result=$(eval "$cmd" 2>/dev/null)
    if echo "$result" | grep -q "$expected"; then
        echo "  [✓] $desc"
        ((PASS++))
    else
        echo "  [✗] $desc"
        echo "      Expected: $expected"
        echo "      Got:      $result"
        ((FAIL++))
    fi
}

echo ""
echo "══════════════════════════════════════════════"
echo "   SOC Lab Health Check"
echo "══════════════════════════════════════════════"

# ── Snort ──────────────────────────────────────────
echo ""
echo "[ Snort IDS/IPS ]"
check "snort-ips service running" \
    "systemctl is-active snort-ips" "active"
check "NFQUEUE rule present in FORWARD chain" \
    "iptables -L FORWARD | grep NFQUEUE" "NFQUEUE"
check "Alert log exists and has content" \
    "test -s /var/log/snort/alert_fast.txt && echo ok" "ok"
check "Snort process using NFQUEUE DAQ" \
    "ps aux | grep snort | grep nfq" "nfq"

# ── Wazuh Agent (Kali) ─────────────────────────────
echo ""
echo "[ Wazuh Agent — Kali ]"
check "wazuh-agent service running" \
    "systemctl is-active wazuh-agent" "active"
check "Agent connected to manager" \
    "grep 'Connected to the server' /var/ossec/logs/ossec.log | tail -1" "Connected"
check "Agent config points to correct manager" \
    "grep -o '192.168.1.33' /var/ossec/etc/ossec.conf" "192.168.1.33"
check "Snort log configured in ossec.conf" \
    "grep snort-fast /var/ossec/etc/ossec.conf" "snort-fast"

# ── Network Reachability ───────────────────────────
echo ""
echo "[ Network Connectivity ]"
check "Wazuh manager reachable (ping)" \
    "ping -c 1 -W 2 $WAZUH_IP" "1 received"
check "Wazuh port 1514 open" \
    "nc -zw2 $WAZUH_IP 1514 && echo open" "open"
check "Wazuh port 443 open (dashboard)" \
    "nc -zw2 $WAZUH_IP 443 && echo open" "open"
check "Shuffle port $SHUFFLE_PORT reachable" \
    "nc -zw2 $SHUFFLE_IP $SHUFFLE_PORT && echo open" "open"
check "Windows victim reachable" \
    "ping -c 1 -W 2 $WINDOWS_IP" "1 received"

# ── IP Forwarding ──────────────────────────────────
echo ""
echo "[ IP Forwarding ]"
check "IP forwarding enabled" \
    "cat /proc/sys/net/ipv4/ip_forward" "1"

# ── Summary ───────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "   Results: $PASS passed / $FAIL failed"
echo "══════════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
    echo "   [✓] All checks passed — lab is healthy!"
else
    echo "   [!] $FAIL check(s) failed — review output above."
    echo "   See troubleshooting/README.md for fixes."
fi
echo ""

# ── Optional: Trigger test alert ──────────────────
read -p "Trigger a test Snort alert now? (ping sweep) [y/N]: " yn
if [[ "$yn" == "y" || "$yn" == "Y" ]]; then
    echo "[*] Sending 10 pings to $WINDOWS_IP..."
    ping -c 10 $WINDOWS_IP > /dev/null
    sleep 2
    echo "[*] Latest alert line:"
    tail -1 /var/log/snort/alert_fast.txt
fi
