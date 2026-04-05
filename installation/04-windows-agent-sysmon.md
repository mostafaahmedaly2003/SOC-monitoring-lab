# Step 4 — Windows Agent + Sysmon

---

## Verify Windows Agent Is Running

Open PowerShell as Administrator:

```powershell
Get-Service -Name WazuhSvc
```
Expected: `Status: Running`

If stopped: `Start-Service WazuhSvc`

Check connectivity to manager:
```powershell
Test-NetConnection -ComputerName 192.168.1.33 -Port 1514
```
Expected: `TcpTestSucceeded: True`

Check agent logs:
```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 10
```
Expected: `Connected to the server (192.168.1.33:1514/tcp).`

---

## Fix Agent If Not Connecting

Open `C:\Program Files (x86)\ossec-agent\ossec.conf` in Notepad as Administrator.

Ensure this block exists with the correct IP:
```xml
<client>
  <server>
    <address>192.168.1.33</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

If agent was never registered:
```powershell
cd "C:\Program Files (x86)\ossec-agent"
.\agent-auth.exe -m 192.168.1.33 -A windows-victim -p 1515
Restart-Service WazuhSvc
```

---

## Install Sysmon

```powershell
# Download Sysmon
Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" `
  -OutFile "$env:TEMP\Sysmon.zip"
Expand-Archive "$env:TEMP\Sysmon.zip" -DestinationPath "$env:TEMP\Sysmon"

# Download SwiftOnSecurity config (best-practice ruleset)
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" `
  -OutFile "$env:TEMP\sysmonconfig.xml"

# Install
& "$env:TEMP\Sysmon\Sysmon64.exe" -accepteula -i "$env:TEMP\sysmonconfig.xml"
```

Expected output: `Sysmon installed. SysmonDrv installed. Starting Sysmon.`

Verify:
```powershell
Get-Service Sysmon64
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 3 | Select TimeCreated, Id
```

---

## Update Windows Agent ossec.conf

Open `C:\Program Files (x86)\ossec-agent\ossec.conf` → add before `</ossec_config>`:

```xml
<localfile>
  <log_format>eventchannel</log_format>
  <location>Microsoft-Windows-Sysmon/Operational</location>
</localfile>

<localfile>
  <log_format>eventchannel</log_format>
  <location>Security</location>
  <query>Event/System[EventID != 5156]</query>
</localfile>

<localfile>
  <log_format>eventchannel</log_format>
  <location>System</location>
</localfile>

<localfile>
  <log_format>eventchannel</log_format>
  <location>Microsoft-Windows-PowerShell/Operational</location>
</localfile>
```

Restart agent:
```powershell
Restart-Service WazuhSvc
Start-Sleep -Seconds 5
(Get-Service WazuhSvc).Status
```

---

## Verify in Wazuh Dashboard

Filter: `agent.name: windows-victim`
Expected: Sysmon events with rule.groups containing `sysmon`

Trigger a test event:
```powershell
Start-Process cmd.exe -ArgumentList "/c whoami"
```
Expected: Sysmon Event ID 1 (process create) appears in dashboard within 30 seconds.
