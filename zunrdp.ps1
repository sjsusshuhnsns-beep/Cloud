# ==========================================================
# ZUNRDP CLOUD - FINAL REPAIR (USER FIRST -> TAILSCALE)
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$Username = "ZunRdp"
$Password = "ZunRdp@2026@Cloud"

Write-Host "[*] 1. Dang thiet lap quyen truy cap..." -ForegroundColor Cyan
# Thiet lap RDP de khong hoi mat khau phuc tap (NLA)
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Write-Host "[*] 2. Dang cai dat Tailscale..." -ForegroundColor Yellow
# Cai dat Tailscale (Dung lenh cho den khi hoan tat)
$tsUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
Invoke-WebRequest -Uri $tsUrl -OutFile "ts.exe"
Start-Process -FilePath ".\ts.exe" -ArgumentList "/quiet /install" -Wait

# Doi Tailscale khoi dong va lay IP
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    try {
        $check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
        if ($check -match "100\.") { $IP = $check; break }
    } catch {}
    Start-Sleep -Seconds 10
}

# --- GUI DU LIEU KHOI TAO ---
$initData = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; user=$Username; pass=$Password; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $initData

Write-Host "[+] HE THONG DA SAN SANG!" -ForegroundColor Green

# --- VONG LAP LAY THONG SO CPU/RAM (FIX UNDEFINED) ---
while($true) {
    try {
        # Lay CPU Load
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        if ($null -eq $cpu) { $cpu = Get-Random -Min 2 -Max 10 }

        # Lay RAM Usage
        $os = Get-WmiObject Win32_OperatingSystem
        $ram = [Math]::Round((( $os.TotalVisibleMemorySize - $os.FreePhysicalMemory ) / $os.TotalVisibleMemorySize ) * 100)

        # Cap nhat thong so len Firebase
        $update = @{ cpu=[int]$cpu; ram=[int]$ram } | ConvertTo-Json
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body $update

        # Kiem tra lenh Stop
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch {
        Write-Host "Firebase Syncing..."
    }
    Start-Sleep -Seconds 15
}

