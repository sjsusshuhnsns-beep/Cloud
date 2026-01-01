Param([string]$Owner, [string]$MachineID)

# Hiện bảng tin ZUNRDP CLOUD lên Desktop
if (Test-Path "C:\ZunTools\Bginfo.exe") {
    Start-Process "C:\ZunTools\Bginfo.exe" -ArgumentList "C:\ZunTools\config.bgi /silent /timer:0 /nolicprompt"
}

# Cấu hình RDP nhanh
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$Username = "ZunRdp"
$Password = (Get-Content "pass.txt" -Raw).Trim()
$Uptime = (Get-Content "uptime.txt" -Raw).Trim()

# --- LẤY IP TAILSCALE ---
$IP = "Connecting..."
for ($i=0; $i -lt 10; $i++) {
    $tsPath = "C:\Program Files\Tailscale\tailscale.exe"
    if (Test-Path $tsPath) {
        $check = (& $tsPath ip -4).Trim()
        if ($check -match "100\.") { $IP = $check; break }
    }
    Start-Sleep -Seconds 2
}

# --- GỬI DỮ LIỆU (FIX LỖI [object Object]) ---
$vmData = @{
    id        = $MachineID
    owner     = $Owner
    ip        = $IP
    user      = $Username
    pass      = "$Password"
    cpu       = 5
    ram       = 15
    startTime = [long]$Uptime
}
$jsonPayload = $vmData | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Put -Body $jsonPayload

# --- CẬP NHẬT BIỂU ĐỒ CPU/RAM ---
while($true) {
    try {
        $cpuLoad = [int](Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $osInfo = Get-WmiObject Win32_OperatingSystem
        $ramLoad = [int][Math]::Round((( $osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory ) / $osInfo.TotalVisibleMemorySize ) * 100)
        
        $updateData = @{ cpu = $cpuLoad; ram = $ramLoad } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Patch -Body $updateData
        
        $cmd = Invoke-RestMethod -Uri "$API/commands/$MachineID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch { }
    Start-Sleep -Seconds 12
}

