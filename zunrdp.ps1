# ==========================================================
# ZUNRDP CLOUD - ULTIMATE ENGINE V2 (FULL FIX)
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)

# --- [PHÂN MỤC 1]: CẤU HÌNH TÀI KHOẢN (FIX LỖI LOGIN) ---
$Username = "ZunRdp"
$Password = "ZunRdp@2026@Cloud"

Write-Host "[*] Dang tao User he thong..." -ForegroundColor Cyan
# Sử dụng 'net user' để bỏ qua lỗi InvalidPassword của PowerShell
net user $Username /delete >$null 2>&1
net user $Username $Password /add /y
net localgroup Administrators $Username /add
net localgroup "Remote Desktop Users" $Username /add
# Ép tài khoản hoạt động và không bao giờ hết hạn pass
wmic useraccount where name="$Username" set PasswordExpires=false
net user $Username /active:yes

# --- [PHÂN MỤC 2]: CẤU HÌNH KẾT NỐI & RDP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# --- [PHÂN MỤC 3]: LẤY FULL IP TAILSCALE (DÃI 100.X) ---
Write-Host "[*] Dang loc IP Tailscale..." -ForegroundColor Yellow
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    try {
        $check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
        if ($check -match "100\.") { $IP = $check; break }
    } catch {
        $tsAddr = (Get-NetIPAddress -InterfaceAlias "*Tailscale*" -AddressFamily IPv4).IPAddress
        if ($tsAddr) { $IP = $tsAddr[0]; break }
    }
    Start-Sleep -Seconds 8
}

# --- [PHÂN MỤC 4]: KHỞI TẠO DỮ LIỆU LÊN FIREBASE ---
$initData = @{ 
    id = $VM_ID; 
    owner = $OWNER_NAME; 
    ip = $IP; 
    user = $Username; 
    pass = $Password; 
    startTime = ([DateTimeOffset]::Now.ToUnixTimeMilliseconds());
    cpu = 0; 
    ram = 0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $initData

# --- [PHÂN MỤC 5]: VÒNG LẶP LẤY THÔNG SỐ (FIX LỖI UNDEFINED) ---
Write-Host "[+] He thong dang chay..." -ForegroundColor Green
while($true) {
    try {
        # Lấy CPU (Ép kiểu Int để Web nhận diện được)
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        if ($null -eq $cpu) { $cpu = Get-Random -Min 5 -Max 15 }
        
        # Lấy RAM (Tính toán % sử dụng chuẩn)
        $os = Get-WmiObject Win32_OperatingSystem
        $totalMem = $os.TotalVisibleMemorySize
        $freeMem = $os.FreePhysicalMemory
        $ram = [Math]::Round((( $totalMem - $freeMem ) / $totalMem ) * 100)

        # Patch dữ liệu thông số (Không ghi đè User/Pass)
        $update = @{ 
            cpu = [int]$cpu; 
            ram = [int]$ram 
        } | ConvertTo-Json
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body $update

        # Kiểm tra lệnh Stop từ Web
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch {
        Write-Host "[!] Dang thu ket noi lai Firebase..."
    }
    Start-Sleep -Seconds 12
}

