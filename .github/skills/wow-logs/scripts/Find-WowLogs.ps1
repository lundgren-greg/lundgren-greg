# Find WoW installs and optionally summarize recent Logs for the active client.
# Usage:
#   .\Find-WowLogs.ps1
#   .\Find-WowLogs.ps1 -Summarize
#   .\Find-WowLogs.ps1 -Client classic

param(
    [switch]$Summarize,
    [ValidateSet('auto', 'classic', 'classic_era', 'anniversary', 'retail')]
    [string]$Client = 'auto',
    [int]$ErrorLines = 12
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-WowRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    $candidates = @(
        'C:\Program Files\Battlenet\World of Warcraft',
        'C:\Program Files (x86)\World of Warcraft',
        'D:\BattlenetLibrary\World of Warcraft',
        'D:\World of Warcraft',
        'C:\World of Warcraft'
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $roots.Add($c) }
    }

    # Battle.net product.db may mention extra paths
    $pdb = "$env:ProgramData\Battle.net\Agent\product.db"
    if (Test-Path $pdb) {
        $bytes = [System.IO.File]::ReadAllBytes($pdb)
        $text = [System.Text.Encoding]::ASCII.GetString($bytes)
        foreach ($m in [regex]::Matches($text, '[A-Z]:\\[^\x00\r\n]{5,120}World of Warcraft')) {
            $p = $m.Value.TrimEnd('\')
            if ((Test-Path $p) -and -not $roots.Contains($p)) { $roots.Add($p) }
        }
    }
    return $roots
}

function Get-BuildInfo([string]$root) {
    $bi = Join-Path $root '.build.info'
    if (-not (Test-Path $bi)) { return @() }
    Get-Content $bi | Select-Object -Skip 1 | ForEach-Object {
        $parts = $_ -split '\|'
        if ($parts.Count -ge 14) {
            [pscustomobject]@{
                Version = $parts[12]
                Product = $parts[14]
            }
        }
    }
}

function Get-ClientFolders([string]$root) {
    $map = @{
        '_classic_'      = 'classic'
        '_classic_era_'  = 'classic_era'
        '_anniversary_'  = 'anniversary'
        '_retail_'       = 'retail'
    }
    Get-ChildItem $root -Directory | Where-Object { $map.ContainsKey($_.Name) } | ForEach-Object {
        $logs = Join-Path $_.FullName 'Logs'
        $newest = $null
        if (Test-Path $logs) {
            $newest = Get-ChildItem $logs -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        [pscustomobject]@{
            Root       = $root
            Folder     = $_.Name
            Kind       = $map[$_.Name]
            Path       = $_.FullName
            LogsPath   = $logs
            HasLogs    = (Test-Path $logs)
            NewestLog  = if ($newest) { $newest.LastWriteTime } else { $null }
            NewestName = if ($newest) { $newest.Name } else { $null }
        }
    }
}

function Show-LogErrors([string]$logsPath) {
    if (-not (Test-Path $logsPath)) { return }
    $patterns = '\[E\]|FATAL|Handle Disconnect|KillConnection|Gpu state has changed|App is background|Load Map Begin|Active Player|Character Login|Client Destroy'
    Get-ChildItem $logsPath -File | Where-Object { $_.Length -gt 0 -and $_.Name -match '\.log$' } | ForEach-Object {
        $hits = Select-String -Path $_.FullName -Pattern $patterns | Select-Object -Last $ErrorLines
        if ($hits) {
            Write-Output ""
            Write-Output "---- $($_.Name) (last matches) ----"
            $hits | ForEach-Object { $_.Line.Substring(0, [Math]::Min(220, $_.Line.Length)) }
        }
    }
}

function Show-Characters([string]$clientPath) {
    $accRoot = Join-Path $clientPath 'WTF\Account'
    if (-not (Test-Path $accRoot)) { return }
    Write-Output ""
    Write-Output "==== Characters (WTF) ===="
    Get-ChildItem $accRoot -Directory | ForEach-Object {
        $account = $_.Name
        Get-ChildItem $_.FullName -Directory | Where-Object { $_.Name -ne 'SavedVariables' } | ForEach-Object {
            $realm = $_.Name
            $chars = (Get-ChildItem $_.FullName -Directory | Select-Object -ExpandProperty Name) -join ', '
            if ($chars) { Write-Output "[$account] $realm : $chars" }
        }
    }
}

# --- main ---
$roots = Get-WowRoots
if (-not $roots -or $roots.Count -eq 0) {
    Write-Output "No World of Warcraft installs found."
    exit 1
}

$all = foreach ($r in $roots) {
    Write-Output "======== ROOT: $r ========"
    $builds = Get-BuildInfo $r
    if ($builds) {
        $builds | ForEach-Object { Write-Output ("  product={0} version={1}" -f $_.Product, $_.Version) }
    }
    Get-ClientFolders $r
}

$clients = @($all | Where-Object { $_ -is [pscustomobject] -and $_.Kind })
if (-not $clients) {
    Write-Output "No client folders (_classic_, etc.) found."
    exit 1
}

Write-Output ""
Write-Output "==== Client folders ===="
$clients |
    Sort-Object NewestLog -Descending |
    Format-Table Kind, Folder, NewestLog, NewestName, Path -AutoSize | Out-String | Write-Output

$target = $null
if ($Client -eq 'auto') {
    $target = $clients | Sort-Object { if ($_.NewestLog) { $_.NewestLog } else { [datetime]::MinValue } } -Descending | Select-Object -First 1
} else {
    $target = $clients | Where-Object { $_.Kind -eq $Client } | Sort-Object NewestLog -Descending | Select-Object -First 1
}

if (-not $target) {
    Write-Output "Requested client '$Client' not found."
    exit 1
}

Write-Output ("Active client: {0} ({1})" -f $target.Kind, $target.Path)
Write-Output ("Logs: {0}" -f $target.LogsPath)

if ($target.HasLogs) {
    Write-Output ""
    Write-Output "==== Log files ===="
    Get-ChildItem $target.LogsPath -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object Name, Length, LastWriteTime |
        Format-Table -AutoSize | Out-String | Write-Output
}

if ($Summarize) {
    Show-LogErrors $target.LogsPath
    Show-Characters $target.Path
    Write-Output ""
    Write-Output "Tip: read Client.log, Connection.log, General.log, gx.log for full detail."
}
