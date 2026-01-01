# ==========================================================
# ZUNRDP CLOUD - VM INITIALIZATION SCRIPT 2026
# ==========================================================

# 1. Cấu hình hình nền tự động từ Link của bạn
$wallpaperUrl = "https://www.mediafire.com/file/zzyg8r3l4ycagr4/vmcloud.png/file?dkey=4crai66gudz&r=1906"
$wallpaperLocal = "C:\Windows\System32\zun_wallpaper.png"

Write-Host "[*] Đang thiết lập giao diện ZunRdp Cloud..." -ForegroundColor Cyan

try {
    # Tải ảnh nền
    Invoke-WebRequest -Uri $wallpaperUrl -OutFile $wallpaperLocal
    
    # Script đổi hình nền ngay lập tức qua API Windows
    $code = @'
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
'@
    Add-Type -TypeDefinition $code
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name wallpaper -Value $wallpaperLocal
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name WallpaperStyle -Value 2
    [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperLocal, 3)
    Write-Host "[+] Đã áp dụng hình nền Cloud thành công!" -ForegroundColor Green
} catch {
    Write-Host "[-] Lỗi tải hình nền, bỏ qua bước này." -ForegroundColor Yellow
}

# 2. Các lệnh cấu hình hệ thống khác (Ví dụ: Cài Chrome, tắt Firewall)
Write-Host "[*] Đang tối ưu hóa hệ thống máy ảo..." -ForegroundColor White
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;

# 3. Kết nối Tailscale (Nếu có dùng)
# tailscale up --authkey $TS_KEY --hostname $OWNER_NAME

Write-Host "==========================================" -ForegroundColor Green
Write-Host "   ZUNRDP CLOUD IS READY TO USE!         " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

