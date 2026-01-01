# ==========================================================
# ZUNRDP CLOUD - ABSOLUTE FIX: USER AUTH & IP
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)

# --- PHÂN MỤC 1: TẠO USER BẰNG PHƯƠNG PHÁP ADSI (ÉP BUỘC) ---
$Username = "ZunRdp"
$Password = "ZunRdp@2026@Cloud"

Write-Host "[*] Dang tao tai khoan he thong..." -ForegroundColor Cyan
try {
    # Xóa user cũ nếu có
    net user $Username /delete >$null 2>&1
    
    # Tạo user mới bằng ADSI để tránh lỗi mật khẩu của PowerShell
    $Computer = [ADSI]"WinNT://$env:COMPUTERNAME"
    $User = $Computer.Create("User", $Username)
    $User.SetPassword($Password)
    $User.SetInfo()
    
    # Thêm vào nhóm quản trị và Remote Desktop
    $AdminGroup = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group"
    $RemoteGroup = [ADSI]"WinNT://$env:COMPUTERNAME/Remote Desktop Users,group"
    $AdminGroup.Add("WinNT://$Username")
    $RemoteGroup.Add("WinNT://$Username")
    
    # Tắt yêu cầu đổi mật khẩu
    $User.UserFlags = 65536 # ADS_UF_DONT_EXPIRE_PASSWD
    $User.SetInfo()
} catch {
    # Nếu ADSI lỗi, dùng net user dự phòng
    net user $Username $Password /add /y
    net localgroup Administrators $Username /add
    net localgroup "Remote Desktop Users" $Username /add
}

# --- PHÂN MỤC 2: LẤY IP TAILSCALE CHUẨN ---
Write-Host "[*] Dang doi Tailscale cap IP..." -ForegroundColor Yellow
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    $TS_Check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4)
    if ($TS_Check -match "100\.") {
        $IP = $TS_Check.Trim()
        break
    }
    Start-Sleep -Seconds 10
}

# --- PHÂN MỤC 3: GỬI DỮ LIỆU ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$Username; pass=$Password; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- PHÂN MỤC 4: HÌNH NỀN & KEEP-ALIVE ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.png"
Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath -ErrorAction SilentlyContinue
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath

while($true) {
    try {
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
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

