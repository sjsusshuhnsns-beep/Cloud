Param([string]$Owner, [string]$MachineID)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$Username = "ZunRdp"
$Password = Get-Content "pass.txt"
$Uptime = Get-Content "uptime.txt"

# --- BƯỚC 1: CẤU HÌNH RDP & HÌNH NỀN ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# Tải hình nền
$wallUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file"
$wallPath = "C:\Windows\zun_wallpaper.jpg"
try { 
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
    rundll32.exe user32.dll,UpdatePerUserSystemParameters 
} catch {}

# --- BƯỚC 2: LẤY IP TAILSCALE ---
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    $check = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()
    if ($check -match "100\.") { $IP = $check; break }
    Start-Sleep -Seconds 5
}

# --- BƯỚC 3: GỬI DỮ LIỆU ĐẦU TIÊN (MẶC ĐỊNH ĐỂ HIỆN THANH LOAD) ---
$initData = @{ 
    id=$MachineID; owner=$Owner; ip=$IP; user=$Username; pass=$Password; 
    cpu=10; ram=20; startTime=[long]$Uptime 
} | ConvertTo-Json
Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Put -Body $initData

# --- BƯỚC 4: CẬP NHẬT THÔNG SỐ LIÊN TỤC (XÓA UNDEFINED) ---
while($true) {
    try {
        # Lấy CPU thực tế (ép kiểu int)
        $cpu = [int](Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        # Lấy RAM thực tế (ép kiểu int)
        $os = Get-WmiObject Win32_OperatingSystem
        $ram = [int][Math]::Round((( $os.TotalVisibleMemorySize - $os.FreePhysicalMemory ) / $os.TotalVisibleMemorySize ) * 100)
        
        # Cập nhật Patch lên Firebase
        Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Patch -Body (@{cpu=$cpu; ram=$ram} | ConvertTo-Json)
        
        # Kiểm tra lệnh stop
        $cmd = Invoke-RestMethod -Uri "$API/commands/$MachineID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch { }
    Start-Sleep -Seconds 12
}

