# Read GrokLocate SavedVariables + optional chat log lines.
# Usage:
#   .\Get-WowPlayerLocation.ps1
#   .\Get-WowPlayerLocation.ps1 -Client classic
#   .\Get-WowPlayerLocation.ps1 -History 5

param(
    [ValidateSet('auto', 'classic', 'classic_era', 'anniversary', 'retail')]
    [string]$Client = 'auto',
    [int]$History = 3,
    [switch]$Json
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-WowRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    foreach ($c in @(
        'C:\Program Files\Battlenet\World of Warcraft',
        'C:\Program Files (x86)\World of Warcraft',
        'D:\BattlenetLibrary\World of Warcraft',
        'D:\World of Warcraft',
        'C:\World of Warcraft'
    )) {
        if (Test-Path $c) { [void]$roots.Add($c) }
    }
    return $roots
}

function Get-ClientDirs([string]$kind) {
    $map = @{
        classic      = '_classic_'
        classic_era  = '_classic_era_'
        anniversary  = '_anniversary_'
        retail       = '_retail_'
    }
    $results = @()
    foreach ($root in Get-WowRoots) {
        if ($kind -eq 'auto') {
            foreach ($folder in $map.Values) {
                $p = Join-Path $root $folder
                if (Test-Path $p) {
                    $results += [pscustomobject]@{ Kind = ($map.GetEnumerator() | Where-Object { $_.Value -eq $folder }).Key; Path = $p; Root = $root }
                }
            }
        } else {
            $p = Join-Path $root $map[$kind]
            if (Test-Path $p) {
                $results += [pscustomobject]@{ Kind = $kind; Path = $p; Root = $root }
            }
        }
    }
    return $results
}

function Parse-GrokLocateFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $raw = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return $null }

    $item = [ordered]@{
        SourceFile   = $path
        FileTime     = (Get-Item $path).LastWriteTime
        LastLine     = $null
        Last         = [ordered]@{}
        History      = @()
    }

    # lastLine = "GRLOC|..."
    if ($raw -match '^\s*\["lastLine"\]\s*=\s*"([^"]*)"' -or $raw -match '^\s*lastLine\s*=\s*"([^"]*)"') {
        # multiline search
    }
    $mLine = [regex]::Match($raw, '\["lastLine"\]\s*=\s*"((?:\\.|[^"\\])*)"')
    if (-not $mLine.Success) {
        $mLine = [regex]::Match($raw, 'lastLine\s*=\s*"((?:\\.|[^"\\])*)"')
    }
    if ($mLine.Success) {
        $item.LastLine = $mLine.Groups[1].Value -replace '\\"', '"'
    }

    # Parse ["last"] = { ... } block (non-greedy enough)
    $lastBlock = [regex]::Match($raw, '\["last"\]\s*=\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $lastBlock.Success) {
        $lastBlock = [regex]::Match($raw, '\[\"last\"\]\s*=\s*\{(.+?)\n\t\},', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    }
    if ($lastBlock.Success) {
        $block = $lastBlock.Groups[1].Value
        $keys = @('ts','reason','player','realm','faction','level','class','zone','zoneText','subzone','minimapZone','mapID','x','y','xPct','yPct','inInstance','instanceType')
        foreach ($k in $keys) {
            $patStr = '\["' + [regex]::Escape($k) + '"\]\s*=\s*"((?:\\.|[^"\\])*)"'
            $patNum = '\["' + [regex]::Escape($k) + '"\]\s*=\s*([0-9.]+)'
            $patBool = '\["' + [regex]::Escape($k) + '"\]\s*=\s*(true|false)'
            if ($block -match $patStr) {
                $item.Last[$k] = $Matches[1] -replace '\\"', '"'
            } elseif ($block -match $patNum) {
                $item.Last[$k] = $Matches[1]
            } elseif ($block -match $patBool) {
                $item.Last[$k] = $Matches[1]
            }
        }
    }

    # Also parse from lastLine GRLOC pipe format if last table thin
    if ($item.LastLine -and $item.LastLine.StartsWith('GRLOC|')) {
        $fromLine = @{}
        foreach ($part in ($item.LastLine -split '\|')) {
            if ($part -match '^([^=]+)=(.*)$') {
                $fromLine[$Matches[1]] = $Matches[2]
            }
        }
        foreach ($k in $fromLine.Keys) {
            if (-not $item.Last.Contains($k) -or [string]::IsNullOrEmpty([string]$item.Last[$k])) {
                $item.Last[$k] = $fromLine[$k]
            }
        }
    }

    return [pscustomobject]$item
}

function Get-ChatLogHits([string]$clientPath, [int]$take = 5) {
    $logs = Join-Path $clientPath 'Logs'
    $hits = @()
    $files = @()
    if (Test-Path $logs) {
        $files += Get-ChildItem $logs -Filter '*Chat*' -File -ErrorAction SilentlyContinue
        $files += Get-ChildItem $logs -Filter 'WoWChatLog*.txt' -File -ErrorAction SilentlyContinue
    }
    $files += Get-ChildItem $clientPath -Filter 'WoWChatLog*.txt' -File -ErrorAction SilentlyContinue
    foreach ($f in ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 3)) {
        $lines = Select-String -Path $f.FullName -Pattern 'GRLOC\|' -ErrorAction SilentlyContinue | Select-Object -Last $take
        foreach ($ln in $lines) {
            $hits += [pscustomobject]@{ File = $f.FullName; Time = $f.LastWriteTime; Line = $ln.Line }
        }
    }
    return $hits
}

# --- main ---
$clients = @(Get-ClientDirs $Client)
if (-not $clients.Count) {
    Write-Output "No WoW clients found."
    exit 1
}

$candidates = @()
foreach ($c in $clients) {
    $svRoot = Join-Path $c.Path 'WTF\Account'
    if (-not (Test-Path $svRoot)) { continue }
    Get-ChildItem $svRoot -Directory | ForEach-Object {
        $sv = Join-Path $_.FullName 'SavedVariables\GrokLocate.lua'
        if (Test-Path $sv) {
            $candidates += [pscustomobject]@{
                Kind = $c.Kind
                ClientPath = $c.Path
                Account = $_.Name
                SvPath = $sv
                Mtime = (Get-Item $sv).LastWriteTime
            }
        }
    }
}

if (-not $candidates.Count) {
    Write-Output "GrokLocate SavedVariables not found yet."
    Write-Output "Enable the GrokLocate addon in-game, then /gloc and /reload (or logout)."
    Write-Output "Clients checked:"
    $clients | ForEach-Object { "  $($_.Kind): $($_.Path)" }
    # Still show chat hits if any
    foreach ($c in $clients) {
        $hits = Get-ChatLogHits $c.Path 3
        if ($hits.Count) {
            Write-Output "`nChat log GRLOC hits ($($c.Kind)):"
            $hits | ForEach-Object { $_.Line }
        }
    }
    exit 2
}

$best = $candidates | Sort-Object Mtime -Descending | Select-Object -First 1
$parsed = Parse-GrokLocateFile $best.SvPath

if ($Json) {
    $parsed | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output "==== GrokLocate ===="
Write-Output ("Client : {0}" -f $best.Kind)
Write-Output ("Account: {0}" -f $best.Account)
Write-Output ("SV file: {0}" -f $best.SvPath)
Write-Output ("Written: {0}" -f $best.Mtime)

if ($parsed -and $parsed.Last -and $parsed.Last.Count -gt 0) {
    $L = $parsed.Last
    Write-Output ""
    Write-Output "---- Last known position ----"
    Write-Output ("Player : {0}-{1}" -f $L.player, $L.realm)
    Write-Output ("Faction: {0}  Level: {1}  Class: {2}" -f $L.faction, $L.level, $L.class)
    Write-Output ("Zone   : {0}" -f $L.zone)
    if ($L.subzone) { Write-Output ("Subzone: {0}" -f $L.subzone) }
    Write-Output ("MapID  : {0}" -f $L.mapID)
    if ($L.xPct -and [double]$L.xPct -ge 0) {
        Write-Output ("Coords : {0}, {1} (percent)" -f $L.xPct, $L.yPct)
    } elseif ($L.x) {
        Write-Output ("Coords : {0}, {1} (0-1)" -f $L.x, $L.y)
    }
    Write-Output ("Instance: {0}" -f $L.instanceType)
    Write-Output ("When   : {0}  reason={1}" -f $L.ts, $L.reason)
} else {
    Write-Output "Could not parse last snapshot; raw lastLine:"
    Write-Output $parsed.LastLine
}

$chatHits = Get-ChatLogHits $best.ClientPath 5
if ($chatHits.Count) {
    Write-Output "`n---- Recent GRLOC chat-log lines ----"
    $chatHits | Select-Object -Last 5 | ForEach-Object { $_.Line.Trim() }
}

Write-Output "`nTip: In-game /gloc then /reload flushes disk. /chatlog enables live lines in Logs."
