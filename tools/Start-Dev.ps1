<#
.SYNOPSIS
  Gets Creature Quest ready to work on, then starts the Rojo server on localhost.

.DESCRIPTION
  1. Installs the pinned tools from rokit.toml (rojo, selene, stylua, gh).
  2. Checks GitHub: gh login, then fetches origin and shows where this branch stands against main.
  3. Creates selene's roblox.yml if it's missing.
  4. Optionally (-UpdateGraph) rebuilds the local Graphify graph and re-applies the Luau require patch.
  5. Starts `rojo serve` on localhost so the Rojo plugin in Studio can connect.

  Connect the Studio plugin only to CQ_NewestSource_TEST.rbxl, never to the published place.

.EXAMPLE
  .\tools\Start-Dev.ps1                 # check everything, then serve on port 34872
  .\tools\Start-Dev.ps1 -UpdateGraph    # also rebuild graphify-out/graph.json first
  .\tools\Start-Dev.ps1 -NoServe        # run the checks only
#>
[CmdletBinding()]
param(
    [int]$Port = 34872,
    [switch]$UpdateGraph,
    [switch]$NoServe
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Has($cmd)  { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Rokit puts tools here; make sure this session can see them.
$rokitBin = Join-Path $env:USERPROFILE '.rokit\bin'
if ((Test-Path $rokitBin) -and ($env:PATH -notlike "*$rokitBin*")) { $env:PATH = "$rokitBin;$env:PATH" }

# 1. Toolchain ---------------------------------------------------------------
Step 'Toolchain (rokit.toml)'
if (-not (Has 'rokit')) {
    throw "rokit is not installed. Run: winget install Rojo.Rokit   then open a new PowerShell window."
}
rokit install | Out-Null
foreach ($t in 'rojo', 'selene', 'stylua', 'gh') {
    if (Has $t) { Ok "$t $((& $t --version 2>$null | Select-Object -First 1))" } else { Warn "$t not found after rokit install" }
}

# 2. GitHub ------------------------------------------------------------------
Step 'GitHub'
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Warn 'gh is not logged in; starting gh auth login (needed for /ship to open PRs)'
    gh auth login --hostname github.com --git-protocol https --web
}
& gh auth status *> $null
if ($LASTEXITCODE -eq 0) { Ok 'gh logged in' } else { Warn 'gh still not logged in' }

git fetch origin --prune --quiet
$branch = git rev-parse --abbrev-ref HEAD
$counts = (git rev-list --left-right --count "origin/main...HEAD") -split '\s+'
Ok "On '$branch': $($counts[1]) commit(s) not on main, $($counts[0]) commit(s) on main not here"
$dirty = git status --porcelain
if ($dirty) { Warn "$(@($dirty).Count) uncommitted change(s) in the working tree" }

# 3. Selene std --------------------------------------------------------------
Step 'Selene'
if (-not (Test-Path 'roblox.yml')) {
    selene generate-roblox-std | Out-Null
    Ok 'Created roblox.yml'
} else { Ok 'roblox.yml present' }

# 4. Graphify (local graph) --------------------------------------------------
Step 'Graphify'
if (-not (Has 'graphify')) {
    Warn 'graphify CLI not found (pip install graphifyy). The Graphify connector in Claude still works without it.'
} elseif ($UpdateGraph) {
    graphify update .
    if ($LASTEXITCODE -ne 0) { throw 'graphify update failed' }
    python tools/graphify_patch_requires.py   # a rebuild drops the Luau require links; this re-adds them
    if ($LASTEXITCODE -ne 0) { throw 'graphify_patch_requires.py failed' }
    Ok 'graphify-out/graph.json rebuilt and patched'
} elseif (Test-Path 'graphify-out\graph.json') {
    Ok "Local graph from $((Get-Item 'graphify-out\graph.json').LastWriteTime) (use -UpdateGraph to rebuild)"
} else {
    Warn 'No graphify-out/graph.json yet; run with -UpdateGraph to build it'
}

# 5. Rojo --------------------------------------------------------------------
if ($NoServe) { Write-Host "`nChecks done (-NoServe)." ; return }

Step "Rojo on localhost:$Port"
# Probe the port by binding it. Get-NetTCPConnection -State Listen can miss Rojo's listener
# (its state shows up blank), so test the bind directly.
$portFree = $true
try {
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    $probe.Start(); $probe.Stop()
} catch { $portFree = $false }
if (-not $portFree) {
    $ownerPid = (Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess
    $proc = if ($ownerPid) { Get-Process -Id $ownerPid -ErrorAction SilentlyContinue }
    if ($proc -and $proc.ProcessName -eq 'rojo') {
        Ok "Rojo is already serving on localhost:$Port (PID $($proc.Id), started $($proc.StartTime)). Connect from Studio, or stop it with: Stop-Process -Id $($proc.Id)"
    } else {
        Warn "Port $Port is in use by $($proc.ProcessName) (PID $ownerPid). Pick another with -Port, and use the same port in the Studio plugin."
    }
    return
}
Write-Host "  In Studio: open CQ_NewestSource_TEST.rbxl > Plugins > Rojo > Connect (localhost:$Port)" -ForegroundColor White
Write-Host '  Press Ctrl+C here to stop the server.' -ForegroundColor White
rojo serve default.project.json --address 127.0.0.1 --port $Port
