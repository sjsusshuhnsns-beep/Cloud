Param ([string]$Owner, [string]$MachineID)
$baseUrl = "https://zunrdp-default-rtdb.asia-southeast1.firebasedatabase.app"
$vmUrl = "$baseUrl/vms/$MachineID.json"
$cmdUrl = "$baseUrl/commands/$MachineID.json"
$pass = (Get-Content "pass.txt" -Raw).Trim()

while($true) {
    try {
        $cmd = Invoke-RestMethod -Uri $cmdUrl -Method Get -ErrorAction SilentlyContinue
        if ($cmd.action -eq "stop") {
            Invoke-RestMethod -Uri $cmdUrl -Method Delete
            Invoke-RestMethod -Uri $vmUrl -Method Delete
            Stop-Computer -Force; exit
        }
        $cpu = [Math]::Round((Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 1)
        $ram = [Math]::Round(((Get-WmiObject Win32_OperatingSystem | % { ($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize }) * 100), 1)
        $ip = (& "C:\Program Files\Tailscale\tailscale.exe" ip -4).Trim()

        $data = @{ id=$MachineID; ip=$ip; owner=$Owner; user="ZunRDP"; pass=$pass; cpu=$cpu; ram=$ram; lastSeen=[DateTimeOffset]::Now.ToUnixTimeMilliseconds() } | ConvertTo-Json
        Invoke-RestMethod -Uri $vmUrl -Method Put -Body $data
    } catch { }
    Start-Sleep -Seconds 5
}

