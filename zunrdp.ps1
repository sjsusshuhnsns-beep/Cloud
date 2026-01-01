# ==========================================================
# ZUNRDP CLOUD - FIXED IP PUBLIC & AUTH
# ==========================================================
Param([string]$OWNER_NAME)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)
$USER_FIXED = "ZunRdp"
$PASS_FIXED = "ZunRdp@2026"

# --- 1. TẠO USER ĐĂNG NHẬP CHUẨN ---
net user $USER_FIXED $PASS_FIXED /add
net localgroup Administrators $USER_FIXED /add
net localgroup "Remote Desktop Users" $USER_FIXED /add

# --- 2. CÀI ĐẶT HÌNH NỀN ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file?dkey=4crai66gudz&r=1906"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    $code = @'
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
'@
    Add-Type -TypeDefinition $code
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    [Wallpaper]::SystemParametersInfo(20, 0, $wallPath, 3)
} catch {}

# --- 3. LẤY IP PUBLIC (BỎ QUA TAILSCALE) ---
# Sử dụng phương pháp gọi API bên ngoài để lấy IP thật của máy ảo
$IP = "Unknown"
try {
    $IP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 10)
} catch {
    # Nếu ipify lỗi, thử server dự phòng
    $IP = (Invoke-RestMethod -Uri "https://ifconfig.me/ip" -TimeoutSec 10)
}

# --- 4. GỬI THÔNG TIN VỀ FIREBASE ---
$data = @{ 
    id=$VM_ID; owner=$OWNER_NAME; ip=$IP; 
    user=$USER_FIXED; pass=$PASS_FIXED; 
    startTime=([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu=0; ram=0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

# --- 5. VÒNG LẶP KEEP-ALIVE ---
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

