# list-tasks.ps1
# Lists all tasks in the current planning session with their status
# Usage: .\list-tasks.ps1 [-SessionDir <path>] [-Filter <status>] [-Verbose]

param(
    [string]$SessionDir = ".planning",
    [ValidateSet("all", "pending", "in-progress", "complete", "blocked", "")]
    [string]$Filter = "all",
    [switch]$Verbose
)

# ANSI color codes for terminal output
$Colors = @{
    Reset     = "`e[0m"
    Bold      = "`e[1m"
    Red       = "`e[31m"
    Green     = "`e[32m"
    Yellow    = "`e[33m"
    Blue      = "`e[34m"
    Magenta   = "`e[35m"
    Cyan      = "`e[36m"
    Gray      = "`e[90m"
}

function Get-StatusColor {
    param([string]$Status)
    switch ($Status.ToLower()) {
        "complete"    { return $Colors.Green }
        "in-progress" { return $Colors.Cyan }
        "blocked"     { return $Colors.Red }
        "pending"     { return $Colors.Yellow }
        default       { return $Colors.Gray }
    }
}

function Get-StatusIcon {
    param([string]$Status)
    switch ($Status.ToLower()) {
        "complete"    { return "[x]" }
        "in-progress" { return "[~]" }
        "blocked"     { return "[!]" }
        "pending"     { return "[ ]" }
        default       { return "[?]" }
    }
}

function Parse-TaskFile {
    param([string]$FilePath)

    $task = @{
        Id          = ""
        Title       = ""
        Status      = "pending"
        Priority    = "medium"
        Description = ""
        Tags        = @()
        File        = $FilePath
    }

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $lines = Get-Content $FilePath
    $inFrontMatter = $false
    $frontMatterDone = $false
    $descLines = @()

    foreach ($line in $lines) {
        if ($line -eq "---" -and -not $frontMatterDone) {
            if (-not $inFrontMatter) {
                $inFrontMatter = $true
                continue
            } else {
                $inFrontMatter = $false
                $frontMatterDone = $true
                continue
            }
        }

        if ($inFrontMatter) {
            if ($line -match '^id:\s*(.+)$')         { $task.Id = $Matches[1].Trim() }
            if ($line -match '^title:\s*(.+)$')      { $task.Title = $Matches[1].Trim() }
            if ($line -match '^status:\s*(.+)$')     { $task.Status = $Matches[1].Trim() }
            if ($line -match '^priority:\s*(.+)$')   { $task.Priority = $Matches[1].Trim() }
            if ($line -match '^tags:\s*\[(.*)\]$') {
                $task.Tags = $Matches[1].Split(',') | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ -ne "" }
            }
        } elseif ($frontMatterDone -and $line -match '^##?\s+Description') {
            # collect description lines after header
        } elseif ($frontMatterDone -and $descLines.Count -lt 3 -and $line.Trim() -ne "") {
            $descLines += $line.Trim()
        }
    }

    if ($task.Title -eq "" -and $task.Id -ne "") {
        $task.Title = $task.Id
    }

    $task.Description = ($descLines | Select-Object -First 2) -join " "
    return $task
}

# Resolve session directory
$resolvedDir = Join-Path (Get-Location) $SessionDir
if (-not (Test-Path $resolvedDir)) {
    Write-Host "$($Colors.Red)Error: Session directory '$SessionDir' not found.$($Colors.Reset)"
    Write-Host "Run init-session.ps1 to create a new planning session."
    exit 1
}

$taskFiles = Get-ChildItem -Path $resolvedDir -Filter "task-*.md" -File | Sort-Object Name

if ($taskFiles.Count -eq 0) {
    Write-Host "$($Colors.Yellow)No tasks found in '$SessionDir'.$($Colors.Reset)"
    exit 0
}

$tasks = $taskFiles | ForEach-Object { Parse-TaskFile $_.FullName } | Where-Object { $_ -ne $null }

# Apply filter
if ($Filter -ne "all" -and $Filter -ne "") {
    $tasks = $tasks | Where-Object { $_.Status.ToLower() -eq $Filter.ToLower() }
}

# Summary counts
$counts = @{ pending = 0; "in-progress" = 0; complete = 0; blocked = 0 }
foreach ($t in ($taskFiles | ForEach-Object { Parse-TaskFile $_.FullName } | Where-Object { $_ -ne $null })) {
    $key = $t.Status.ToLower()
    if ($counts.ContainsKey($key)) { $counts[$key]++ } else { $counts[$key] = 1 }
}

Write-Host ""
Write-Host "$($Colors.Bold)Planning Session: $SessionDir$($Colors.Reset)"
Write-Host "$($Colors.Gray)────────────────────────────────────────$($Colors.Reset)"
Write-Host ("  {0}pending{1}: {2}   {3}in-progress{4}: {5}   {6}complete{7}: {8}   {9}blocked{10}: {11}" -f `
    $Colors.Yellow, $Colors.Reset, $counts["pending"], `
    $Colors.Cyan,   $Colors.Reset, $counts["in-progress"], `
    $Colors.Green,  $Colors.Reset, $counts["complete"], `
    $Colors.Red,    $Colors.Reset, $counts["blocked"])
Write-Host "$($Colors.Gray)────────────────────────────────────────$($Colors.Reset)"
Write-Host ""

if ($tasks.Count -eq 0) {
    Write-Host "$($Colors.Gray)  No tasks match filter: $Filter$($Colors.Reset)"
} else {
    foreach ($task in $tasks) {
        $icon  = Get-StatusIcon  $task.Status
        $color = Get-StatusColor $task.Status
        $id    = $task.Id.PadRight(20)
        $title = if ($task.Title.Length -gt 40) { $task.Title.Substring(0,37) + "..." } else { $task.Title }

        Write-Host ("  {0}{1}{2} {3}{4}{5}  {6}" -f `
            $color, $icon, $Colors.Reset, `
            $Colors.Bold, $title, $Colors.Reset, `
            $task.Id)

        if ($Verbose -and $task.Description -ne "") {
            Write-Host "       $($Colors.Gray)$($task.Description)$($Colors.Reset)"
        }

        if ($Verbose -and $task.Tags.Count -gt 0) {
            $tagStr = ($task.Tags | ForEach-Object { "#$_" }) -join "  "
            Write-Host "       $($Colors.Magenta)$tagStr$($Colors.Reset)"
        }
    }
}

Write-Host ""
