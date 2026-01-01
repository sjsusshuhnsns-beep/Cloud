# ==========================================================
# ZUNRDP CLOUD ENGINE - FIXED USER & WALLPAPER
# ==========================================================
Param(
    [string]$OWNER_NAME
)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$VM_ID = "ZUN-" + (Get-Random -Minimum 1000 -Maximum 9999)

# --- CÀI ĐẶT HÌNH NỀN CHO USER ZunRdp ---
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file?dkey=4crai66gudz&r=1906"
$wallPath = "C:\Windows\zun_wallpaper.png"

try {
    # Tải ảnh về máy
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath
    
    # Lệnh API Windows để đổi nền ngay lập tức
    $code = @'
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
'@
    Add-Type -TypeDefinition $code
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name WallpaperStyle -Value 2
    [Wallpaper]::SystemParametersInfo(20, 0, $wallPath, 3)
} catch {
    Write-Host "Khong tai duoc hinh nen, kiem tra lai link!" -ForegroundColor Red
}

# --- LẤY IP PUBLIC VÀ CỐ ĐỊNH USER ---
$IP = (Invoke-RestMethod -Uri "https://api.ipify.org")
$FIXED_USER = "ZunRdp"
$PASS = "ZunRdp@2026"

# --- GỬI DỮ LIỆU LÊN FIREBASE ---
$data = @{ 
    id = $VM_ID; 
    owner = $OWNER_NAME; 
    ip = $IP; 
    user = $FIXED_USER; 
    pass = $PASS; 
    startTime = ([DateTimeOffset]::Now.ToUnixTimeMilliseconds()); 
    cpu = 0; 
    ram = 0 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Put -Body $data

Write-Host "VM UP! User: $FIXED_USER | IP: $IP" -ForegroundColor Green

# --- VÒNG LẶP TREO MÁY (KEEP-ALIVE) ---
while($true) {
    try {
        # Check lệnh tắt máy từ trang Web
        $cmd = Invoke-RestMethod -Uri "$API/commands/$VM_ID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Delete
            Invoke-RestMethod -Uri "$API/commands/$VM_ID.json" -Method Delete
            Stop-Computer -Force
            break
        }

        # Cập nhật thông số CPU/RAM
        $mem = Get-WmiObject Win32_OperatingSystem
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $ram = [Math]::Round((( $mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory ) / $mem.TotalVisibleMemorySize ) * 100)

        $upd = @{ cpu=$cpu; ram=$ram } | ConvertTo-Json
        Invoke-RestMethod -Uri "$API/vms/$VM_ID.json" -Method Patch -Body $upd
    } catch {
        # Nếu mất mạng tạm thời thì đợi để thử lại
    }
    Start-Sleep -Seconds 10
}

