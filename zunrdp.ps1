# ==========================================================
# ZUNRDP CLOUD - ENGINE V2026 (FIXED AUTH & TAILSCALE)
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)

# --- PHÂN MỤC 1: CẤU HÌNH USER & MẬT KHẨU ---
$USER_FIXED = "ZunRdp"
$PASS_FIXED = "ZunRdp@2026@Cloud"

Write-Host "[*] Dang tao User: $USER_FIXED" -ForegroundColor Cyan
net user $USER_FIXED /delete >$null 2>&1
net user $USER_FIXED $PASS_FIXED /add /y
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add
wmic useraccount where "Name='$USER_FIXED'" set PasswordExpires=FALSE

# --- PHÂN MỤC 2: LẤY FULL IP TAILSCALE ---
Write-Host "[*] Dang doi Tailscale cap IP (100.x.x.x)..." -ForegroundColor Yellow
$IP = "Connecting..."
$retry = 0
while ($IP -match "Connecting" -and $retry -lt 20) {
    try {
        $rawIP = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
        if ($rawIP -match "100\.") { $IP = $rawIP }
    } catch {
        $TS_IP = (Get-NetIPAddress -InterfaceAlias "*Tailscale*" -AddressFamily IPv4).IPAddress
        if ($TS_IP) { $IP = $TS_IP[0] }
    }
    if ($IP -match "Connecting") { $retry++; Start-Sleep -Seconds 10 }
}

# --- PHÂN MỤC 3: CÀI ĐẶT HÌNH NỀN ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    rundll32.exe user32.dll,UpdatePerUserSystemParameters
} catch {}

# --- PHÂN MỤC 4: GỬI DỮ LIỆU & DUY TRÌ ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$USER_FIXED; pass=$PASS_FIXED; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

while($true) {
    try {
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Invoke-RestMethod -Uri "$API/commands/$VM_ID.json" -Method Delete
            Stop-Computer -Force
            break
        }
        $mem = Get-WmiObject Win32_OperatingSystem
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $ram = [Math]::Round((( $mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory ) / $mem.TotalVisibleMemorySize ) * 100)
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body (@{cpu=$cpu; ram=$ram} | ConvertTo-Json)
    } catch {}
    Start-Sleep -Seconds 10
}

