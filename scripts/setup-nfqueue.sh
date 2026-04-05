#!/bin/bash
# =============================================================
# setup-nfqueue.sh — Configure iptables NFQUEUE for Snort IPS
# Run as root on Kali Linux
# Interface: eth2 (modify IFACE if different)
# =============================================================

set -e

IFACE="eth2"
QUEUE_NUM=0

echo "[*] Loading NFQUEUE kernel module..."
modprobe nfnetlink_queue
lsmod | grep -q nfnetlink_queue && echo "[+] Module loaded." || { echo "[-] Failed to load module."; exit 1; }

echo "[*] Clearing existing NFQUEUE rules..."
iptables -D FORWARD -j NFQUEUE --queue-num $QUEUE_NUM 2>/dev/null || true
iptables -D INPUT  -i $IFACE -j NFQUEUE --queue-num $QUEUE_NUM 2>/dev/null || true
iptables -D OUTPUT -o $IFACE -j NFQUEUE --queue-num $QUEUE_NUM 2>/dev/null || true

echo "[*] Adding NFQUEUE rules for interface $IFACE..."
iptables -I FORWARD -j NFQUEUE --queue-num $QUEUE_NUM
iptables -I INPUT  -i $IFACE -j NFQUEUE --queue-num $QUEUE_NUM
iptables -I OUTPUT -o $IFACE -j NFQUEUE --queue-num $QUEUE_NUM

echo "[*] Verifying rules..."
iptables -L FORWARD --line-numbers | head -5
iptables -L INPUT   --line-numbers | head -5

echo ""
echo "[+] NFQUEUE rules configured successfully."
echo "[*] To make persistent across reboots:"
echo "    sudo netfilter-persistent save"
