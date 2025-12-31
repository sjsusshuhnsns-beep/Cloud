Param ([string]$Owner, [string]$MachineID)
$baseUrl = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$pass = (Get-Content "pass.txt" -Raw).Trim()
$startTime = (Get-Content "uptime.txt" -Raw).Trim()

while($true) {
    try {
        # Check Ban/Stop
        $cmd = Invoke-RestMethod -Uri "$baseUrl/commands/$MachineID.json" -Method Get -ErrorAction SilentlyContinue
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri "$baseUrl/commands/$MachineID.json" -Method Delete
            Invoke-RestMethod -Uri "$baseUrl/vms/$MachineID.json" -Method Delete
            Stop-Computer -Force; exit
        }

        $cpu = [Math]::Round((Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 1)
        $ram = [Math]::Round(((Get-WmiObject Win32_OperatingSystem | % { ($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize }) * 100), 1)
        $ip = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()

        $data = @{ 
            id=$MachineID; ip=$ip; owner=$Owner; user="ZunRDP"; pass=$pass; 
            cpu=$cpu; ram=$ram; startTime=$startTime; 
            lastSeen=[DateTimeOffset]::Now.ToUnixTimeMilliseconds() 
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "$baseUrl/vms/$MachineID.json" -Method Put -Body $data
    } catch { }
    Start-Sleep -Seconds 5
}

