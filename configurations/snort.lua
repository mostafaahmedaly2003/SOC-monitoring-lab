-- =============================================================
-- Snort 3 Main Configuration — SOC Lab
-- Interface: eth2 (10.94.117.59)
-- Mode: IPS inline via iptables NFQUEUE
-- Alert output: /var/log/snort/alert_fast.txt
-- =============================================================

-- Protected networks (all internal subnets)
HOME_NET = '192.168.1.0/24,10.94.117.0/24,192.168.61.0/24'
EXTERNAL_NET = '!$HOME_NET'

-- Load default variable definitions
include 'snort_defaults.lua'

-- Stream reassembly (required for proper TCP/UDP tracking)
stream = {}
stream_tcp = {}
stream_udp = {}
stream_icmp = {}

-- HTTP inspection
http_inspect = {}

-- Fast alert output — one line per alert, written to file
-- Wazuh agent reads this file with log_format: snort-fast
alert_fast =
{
    file   = true,    -- write to /var/log/snort/alert_fast.txt
    packet = false,   -- don't dump raw packet bytes
    limit  = 10,      -- rotate log file at 10 MB
}

-- IPS rules configuration
ips =
{
    enable_builtin_rules = true,
    rules = [[
        include /etc/snort/rules/local.rules
        -- Uncomment below after downloading community rules:
        -- include /etc/snort/rules/snort3-community.rules
    ]],
}
