Param([string]$Owner, [string]$MachineID)

$API = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$Username = "ZunRdp"

# Đảm bảo lấy mật khẩu dạng chuỗi văn bản sạch
$PasswordRaw = Get-Content "pass.txt" -Raw
$Password = $PasswordRaw.Trim()
$Uptime = Get-Content "uptime.txt" -Raw

# --- [1] CÀI ĐẶT HÌNH NỀN DISCORD ---
$wallUrl = "https://cdn.discordapp.com/attachments/1452161479166918706/1456105809174986782/vmcloud.png?ex=695727b6&is=6955d636&hm=7c858e40d73738a2415807a9a56de20fb94ef35eb8af3f3a856025dd70fd9ba7&"
$wallPath = "C:\Windows\zun_wallpaper.png"
try {
    Invoke-WebRequest -Uri $wallUrl -OutFile $wallPath -ErrorAction SilentlyContinue
    if (Test-Path $wallPath) {
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallPath
        rundll32.exe user32.dll,UpdatePerUserSystemParameters
    }
} catch { }

# --- [2] CẤU HÌNH RDP ---
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# --- [3] LẤY IP TAILSCALE ---
$IP = "Connecting..."
for ($i=0; $i -lt 15; $i++) {
    $tsPath = "C:\Program Files\Tailscale\tailscale.exe"
    if (Test-Path $tsPath) {
        $check = (& $tsPath ip -4).Trim()
        if ($check -match "100\.") { $IP = $check; break }
    }
    Start-Sleep -Seconds 5
}

# --- [4] GỬI DỮ LIỆU BAN ĐẦU (QUAN TRỌNG: FIX LỖI MK) ---
# Sử dụng bảng băm và chuyển đổi sang JSON chuẩn để Web nhận diện được String
$vmData = @{
    id        = $MachineID
    owner     = $Owner
    ip        = $IP
    user      = $Username
    pass      = "$Password"  # Ép kiểu String bằng dấu ngoặc kép
    cpu       = 10
    ram       = 20
    startTime = [long]$Uptime.Trim()
}
$jsonPayload = $vmData | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Put -Body $jsonPayload

# --- [5] CẬP NHẬT THÔNG SỐ LIÊN TỤC ---
while($true) {
    try {
        $cpuLoad = [int](Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $osInfo = Get-WmiObject Win32_OperatingSystem
        $ramLoad = [int][Math]::Round((( $osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory ) / $osInfo.TotalVisibleMemorySize ) * 100)
        
        $updateData = @{ cpu = $cpuLoad; ram = $ramLoad } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Patch -Body $updateData
        
        # Check lệnh Kill từ Web
        $cmd = Invoke-RestMethod -Uri "$API/commands/$MachineID.json"
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$API/vms/$MachineID.json" -Method Delete
            Stop-Computer -Force; break
        }
    } catch { }
    Start-Sleep -Seconds 12
}

