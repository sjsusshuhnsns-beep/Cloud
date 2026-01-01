# ==========================================================
# ZUNRDP CLOUD - FINAL FIX: AUTH & TAILSCALE IP
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$USER_FIXED = "ZunRDP"
$PASS_FIXED = "ZunRdp@2026@Cloud" # Mật khẩu siêu mạnh để fix lỗi InvalidPassword

Write-Host "[*] Dang thiet lap User: $USER_FIXED" -ForegroundColor Cyan

# --- 1. TAO USER BANG NET USER (FIX LOI PASSWORD) ---
# Xóa user cũ nếu lỡ tồn tại để tránh xung đột
net user $USER_FIXED /delete >$null 2>&1
# Tạo mới với chính sách bỏ qua kiểm tra độ phức tạp của PS
net user $USER_FIXED $PASS_FIXED /add /y
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add
# Đảm bảo mật khẩu không bao giờ hết hạn
wmic useraccount where "Name='$USER_FIXED'" set PasswordExpires=FALSE

# --- 2. LAY CHINH XAC IP TAILSCALE ---
Write-Host "[*] Dang quet mang Tailscale..." -ForegroundColor Yellow
Start-Sleep -Seconds 8 # Đợi Tailscale ổn định
$IP = "0.0.0.0"
$TS_IP = (Get-NetIPAddress -InterfaceAlias "*Tailscale*" -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress

if ($TS_IP) {
    $IP = $TS_IP[0] # Lấy IP đầu tiên nếu có nhiều IP
    Write-Host "[+] Da tim thay IP Tailscale: $IP" -ForegroundColor Green
} else {
    $IP = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
    Write-Host "[!] Khong thay Tailscale, dung IP Public: $IP" -ForegroundColor Red
}

# --- 3. CAI ANH NEN ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    rundll32.exe user32.dll,UpdatePerUserSystemParameters
} catch {}

# --- 4. GUI DU LIEU VE FIREBASE ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$USER_FIXED; pass=$PASS_FIXED; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 5. VONG LAP TREO MAY (KEEP-ALIVE) ---
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

