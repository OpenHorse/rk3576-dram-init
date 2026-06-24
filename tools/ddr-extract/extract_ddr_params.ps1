#Requires -Version 5.1
<#
.SYNOPSIS
    Dump the real DDR parameter values Rockchip ships inside an RK3576 DDR blob,
    using Jonas Karlman's open-source ddrbin_tool.py (github.com/Kwiboo/rkbin-2).

.DESCRIPTION
    Reads only the *parameter block* (frequencies, ODT/drive ohms, VREF, slew,
    CA/DQ skew, CA/byte/DQ swap, address-hash masks). It does NOT disassemble or
    extract init/training code. The values are board-tuning data, usable as
    authoritative starting points for a from-source driver.

    Caveat: the rkbin-2 fork has per-chip config blocks only up to rk3588/rv1126b;
    rk3576 is recognised but may not have a dedicated block. If the rk3576 run
    fails, this script retries with the rk3588 layout as a proxy (the v7 struct
    layout is shared). Proxied output is tagged; verify it against the TRM.

.PARAMETER Blob
    Path to the RK3576 DDR .bin (from rockchip-linux/rkbin).

.PARAMETER MaxGroups
    Number of ADC config groups to try (1 for single-config blobs).

.PARAMETER OutDir
    Output directory for the gen_*.txt dumps.

.EXAMPLE
    .\extract_ddr_params.ps1 -Blob rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin

.EXAMPLE
    .\extract_ddr_params.ps1 -Blob rk3576_ddr_..._v1.13.bin -MaxGroups 12 -OutDir .\extracted
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Blob,
    [int]$MaxGroups = 1,
    [string]$OutDir = './extracted'
)

$ErrorActionPreference = 'Stop'

$ToolRepo = 'https://github.com/Kwiboo/rkbin-2.git'
$ToolDir  = if ($env:DDRBIN_TOOL_DIR) { $env:DDRBIN_TOOL_DIR } else { './rkbin-2' }
$Types    = @('LPDDR5', 'LPDDR4', 'LPDDR4X')
$Chips    = @('rk3576', 'rk3588')   # primary, then proxy fallback

function Die([string]$Message) { Write-Error $Message; exit 1 }

# --- validate input ---
if (-not (Test-Path -LiteralPath $Blob -PathType Leaf)) { Die "blob not found: $Blob" }
if ($MaxGroups -lt 1) { Die 'MaxGroups must be >= 1' }

# --- find a python interpreter ---
$Python = $null
foreach ($p in @('python', 'python3', 'py')) {
    if (Get-Command $p -ErrorAction SilentlyContinue) { $Python = $p; break }
}
if (-not $Python) { Die 'python not found (need python3 in PATH)' }

# --- locate or fetch the tool ---
$Tool = $null
$cand = Join-Path (Join-Path $ToolDir 'tools') 'ddrbin_tool.py'
if (Test-Path -LiteralPath $cand) {
    $Tool = $cand
}
elseif (Get-Command 'ddrbin_tool.py' -ErrorAction SilentlyContinue) {
    $Tool = (Get-Command 'ddrbin_tool.py').Source
}
else {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die 'git required to fetch the tool' }
    Write-Host "ddrbin_tool.py not found; cloning $ToolRepo -> $ToolDir"
    git clone --depth 1 $ToolRepo $ToolDir
    $Tool = $cand
}
if (-not (Test-Path -LiteralPath $Tool)) { Die "ddrbin_tool.py not found at $Tool" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "tool  : $Tool"
Write-Host "blob  : $Blob"
Write-Host "out   : $OutDir"
Write-Host ("groups: 1..{0}, types: {1}" -f $MaxGroups, ($Types -join ', '))
Write-Host ''

# Try one extraction; return $true on success.
function Invoke-Dump([string]$Chip, [string]$Type, [int]$Group, [string]$OutFile) {
    $cmdArgs = @($Tool, $Chip, '-g', $OutFile, $Blob, $Type)
    if ($Group -gt 0) { $cmdArgs += "adc_value_to_ddr_config=$Group" }
    & $Python @cmdArgs *> $null
    return ($LASTEXITCODE -eq 0)
}

$ok = 0; $fail = 0
foreach ($type in $Types) {
    for ($g = 1; $g -le $MaxGroups; $g++) {
        $outFile  = Join-Path $OutDir ('gen_{0}_group{1}.txt' -f $type.ToLower(), $g)
        $usedChip = $null
        foreach ($chip in $Chips) {
            # Single-group blobs ignore the group arg; pass 0 when MaxGroups -eq 1.
            $grpArg = if ($MaxGroups -eq 1) { 0 } else { $g }
            if (Invoke-Dump $chip $type $grpArg $outFile) { $usedChip = $chip; break }
        }
        if ($usedChip -and (Test-Path -LiteralPath $outFile) -and ((Get-Item -LiteralPath $outFile).Length -gt 0)) {
            $tag = if ($usedChip -eq 'rk3576') { '' } else { "  [PROXY:$usedChip - verify vs TRM]" }
            Write-Host "  ok   $outFile$tag"
            $ok++
        }
        else {
            if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
            $fail++
        }
    }
}

Write-Host ''
Write-Host "done: $ok extracted, $fail skipped (type/group not present in this blob)."
if ($ok -eq 0) { Die 'nothing extracted - check the blob path, type, and group count.' }
Write-Host "next: $Python ddrparam_to_inc.py $OutDir/gen_lpddr5_group1.txt > rk3576-lpddr5-extracted.txt"
