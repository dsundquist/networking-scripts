@echo off
:: =================================================================
:: mtr.bat  -  MTR-style per-hop latency and loss report for Windows
:: Usage  : mtr.bat <destination> [count]
::
::   destination   Hostname, IPv4 address, or IPv6 address to trace
::   count         Number of pings per hop  (default: 10)
::
:: Examples:
::   mtr.bat 1.1.1.1
::   mtr.bat google.com 20
::   mtr.bat 2606:4700:4700::1111 15
::
:: Requires: PowerShell (built into Windows 7+)
:: =================================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create(((Get-Content -Raw '%~f0') -replace '(?s)^.*?#!powershell\r?\n',''))) %*"
goto :eof
#!powershell
param(
    [Parameter(Position=0)][string]$Destination = "",
    [Parameter(Position=1)][string]$CountRaw = "10"
)

# Convert count to int, fall back to 10 on bad input
$Count = 10
try { $Count = [int]$CountRaw } catch { }
if ($Count -lt 1) { $Count = 10 }

if (-not $Destination) {
    Write-Host ""
    Write-Host "  Usage: mtr.bat <destination> [count]"
    Write-Host ""
    Write-Host "    destination   Hostname, IPv4 address, or IPv6 address"
    Write-Host "    count         Pings per hop  (default: 10)"
    Write-Host ""
    Write-Host "  Examples:"
    Write-Host "    mtr.bat 1.1.1.1"
    Write-Host "    mtr.bat google.com 20"
    Write-Host "    mtr.bat 2606:4700:4700::1111 15"
    Write-Host ""
    exit 1
}

$isIPv6 = ($Destination -match ':')

Write-Host ""
Write-Host "[ mtr.bat ]  Discovering route to $Destination  (please wait) ..."

# Run tracert with -d (no DNS resolution) for speed
if ($isIPv6) {
    $tracertOutput = & tracert -6 -d -h 30 -w 2000 $Destination 2>&1
} else {
    $tracertOutput = & tracert -d -h 30 -w 2000 $Destination 2>&1
}

# Parse hop lines from tracert output
$hops = [System.Collections.Generic.List[hashtable]]::new()
foreach ($line in $tracertOutput) {
    $line = "$line".Trim()
    if ($line -notmatch '^(\d+)\s+') { continue }
    $hopNum = [int]$Matches[1]

    if ($line -match 'Request timed out|Destination host unreachable' -or
        $line -match '^\d+(\s+\*){3}') {
        $hops.Add(@{ Hop = $hopNum; IP = "*"; Timeout = $true })
    } elseif ($line -match '(\d{1,3}(?:\.\d{1,3}){3})\s*$') {
        $hops.Add(@{ Hop = $hopNum; IP = $Matches[1]; Timeout = $false })
    } elseif ($line -match '([0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{0,4}){2,7})\s*$') {
        $hops.Add(@{ Hop = $hopNum; IP = $Matches[1]; Timeout = $false })
    }
}

if ($hops.Count -eq 0) {
    Write-Host ""
    Write-Host "  No hops discovered. Check connectivity and whether ICMP is blocked."
    Write-Host ""
    exit 1
}

Write-Host "[ mtr.bat ]  Found $($hops.Count) hop(s). Launching $Count ping(s) per hop in parallel ..."
Write-Host ""

# Fire off all hops simultaneously as background jobs
$jobList = [System.Collections.Generic.List[hashtable]]::new()
foreach ($hop in $hops) {
    if ($hop.Timeout) {
        $jobList.Add(@{ Hop = $hop; Job = $null })
        continue
    }
    $job = Start-Job -ScriptBlock {
        param($ip, $count, $isIPv6)
        if ($isIPv6) {
            & ping -6 -n $count -w 1000 $ip 2>&1
        } else {
            & ping -n $count -w 1000 $ip 2>&1
        }
    } -ArgumentList $hop.IP, $Count, $isIPv6
    $jobList.Add(@{ Hop = $hop; Job = $job })
}

Write-Host "[ mtr.bat ]  Collecting results ..."

# Wait on each job in order and parse output (all jobs are already running in parallel)
$results = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($item in $jobList) {
    $hop = $item.Hop

    # All-timeout hops get a placeholder row
    if (-not $item.Job) {
        $results.Add([PSCustomObject]@{
            Hop  = $hop.Hop
            Host = "???"
            Loss = "100.0%"
            Snt  = $Count
            Rcv  = 0
            Last = "???"
            Avg  = "???"
            Best = "???"
            Wrst = "???"
        })
        continue
    }

    $pingOutput = Receive-Job -Job $item.Job -Wait
    Remove-Job -Job $item.Job -Force

    $ip        = $hop.IP
    $times     = [System.Collections.Generic.List[int]]::new()
    $sentCount = 0
    $recvCount = 0

    foreach ($pline in $pingOutput) {
        $pline = "$pline"
        # Parse summary line: "Packets: Sent = X, Received = Y, Lost = Z"
        if ($pline -match 'Sent\s*=\s*(\d+).*?Received\s*=\s*(\d+)') {
            $sentCount = [int]$Matches[1]
            $recvCount = [int]$Matches[2]
        }
        # Parse individual reply times: time=Xms or time<Xms (e.g. time<1ms)
        if ($pline -match 'time[=<](\d+)ms') {
            $times.Add([int]$Matches[1])
        }
    }

    # Fall back to derived counts if summary line was not found
    if ($sentCount -eq 0) { $sentCount = $Count }
    if ($recvCount -eq 0) { $recvCount = $times.Count }

    $lossVal = if ($sentCount -gt 0) {
        [math]::Round((($sentCount - $recvCount) / $sentCount) * 100, 1)
    } else { 100.0 }

    if ($times.Count -gt 0) {
        $lastMs  = $times[$times.Count - 1]
        $avgMs   = [math]::Round(($times | Measure-Object -Average).Average, 1)
        $bestMs  = ($times | Measure-Object -Minimum).Minimum
        $worstMs = ($times | Measure-Object -Maximum).Maximum
        $lastStr  = "${lastMs}ms"
        $avgStr   = "${avgMs}ms"
        $bestStr  = "${bestMs}ms"
        $worstStr = "${worstMs}ms"
    } else {
        $lastStr = $avgStr = $bestStr = $worstStr = "???"
    }

    $results.Add([PSCustomObject]@{
        Hop  = $hop.Hop
        Host = $ip
        Loss = "$lossVal%"
        Snt  = $sentCount
        Rcv  = $recvCount
        Last = $lastStr
        Avg  = $avgStr
        Best = $bestStr
        Wrst = $worstStr
    })
}

# Print the report table
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$fmt  = "{0,-4} {1,-39} {2,7} {3,4} {4,4} {5,8} {6,8} {7,8} {8,8}"
$hdr  = $fmt -f "Hop","Host","Loss%","Snt","Rcv","Last","Avg","Best","Wrst"
$sep  = "-" * $hdr.Length

Write-Host "MTR Report"
Write-Host ("From:        {0}" -f $env:COMPUTERNAME)
Write-Host ("Date:        {0}" -f $date)
Write-Host ("Destination: {0}" -f $Destination)
Write-Host ("Pings/Hop:   {0}" -f $Count)
Write-Host ""
Write-Host $hdr
Write-Host $sep
foreach ($r in $results) {
    Write-Host ($fmt -f $r.Hop, $r.Host, $r.Loss, $r.Snt, $r.Rcv, $r.Last, $r.Avg, $r.Best, $r.Wrst)
}
Write-Host $sep
Write-Host ""
