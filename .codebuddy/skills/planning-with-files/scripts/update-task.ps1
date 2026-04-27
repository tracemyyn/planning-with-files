# update-task.ps1
# Updates the status or details of a task in the planning session files
# Usage: .\update-task.ps1 -TaskId <id> -Status <status> [-Notes <notes>] [-SessionDir <dir>]

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Mandatory=$true)]
    [ValidateSet("pending", "in-progress", "blocked", "complete", "skipped")]
    [string]$Status,

    [Parameter(Mandatory=$false)]
    [string]$Notes = "",

    [Parameter(Mandatory=$false)]
    [string]$SessionDir = ".codebuddy/session"
)

$ErrorActionPreference = "Stop"

# Resolve session directory
$SessionPath = Join-Path (Get-Location) $SessionDir

if (-not (Test-Path $SessionPath)) {
    Write-Error "Session directory not found: $SessionPath"
    Write-Host "Run init-session.ps1 first to initialize a planning session."
    exit 1
}

# Locate the tasks file
$TasksFile = Join-Path $SessionPath "tasks.md"

if (-not (Test-Path $TasksFile)) {
    Write-Error "Tasks file not found: $TasksFile"
    exit 1
}

# Read current content
$Content = Get-Content $TasksFile -Raw

# Status symbol mapping
$StatusSymbols = @{
    "pending"     = "[ ]"
    "in-progress" = "[~]"
    "blocked"     = "[!]"
    "complete"    = "[x]"
    "skipped"     = "[-]"
}

$NewSymbol = $StatusSymbols[$Status]

# Pattern to match any task line with the given TaskId
# Expected format: - [x] TASK-001: Description
$Pattern = '(?m)^(\s*- )\[[~!x \-]\]( ' + [regex]::Escape($TaskId) + ':.*?)$'

if ($Content -notmatch $Pattern) {
    Write-Error "Task '$TaskId' not found in $TasksFile"
    exit 1
}

# Replace the status symbol
$UpdatedContent = [regex]::Replace($Content, $Pattern, "`$1$NewSymbol`$2")

# Append notes if provided
if ($Notes -ne "") {
    $Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm")
    $NoteEntry = "`n  > [$Timestamp] $Notes"

    # Insert note after the matching task line
    $NotePattern = '(?m)(^\s*- \[[~!x \-]\] ' + [regex]::Escape($TaskId) + ':.*?)$'
    $UpdatedContent = [regex]::Replace($UpdatedContent, $NotePattern, "`$1$NoteEntry")
}

# Write updated content back
Set-Content -Path $TasksFile -Value $UpdatedContent -NoNewline

Write-Host "Task '$TaskId' updated to status '$Status'."

if ($Notes -ne "") {
    Write-Host "Note appended: $Notes"
}

# Update the session log
$LogFile = Join-Path $SessionPath "session.log"
$Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$LogEntry = "[$Timestamp] Task '$TaskId' -> $Status"

if ($Notes -ne "") {
    $LogEntry += " | Note: $Notes"
}

Add-Content -Path $LogFile -Value $LogEntry

Write-Host "Session log updated."
