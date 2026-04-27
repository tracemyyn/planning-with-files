# get-task.ps1
# Retrieves details of a specific task from the planning session
# Usage: .\get-task.ps1 -TaskId <task-id> [-SessionDir <path>]

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Mandatory=$false)]
    [string]$SessionDir = ".codebuddy/sessions"
)

# Resolve session directory
$resolvedSessionDir = Resolve-Path $SessionDir -ErrorAction SilentlyContinue
if (-not $resolvedSessionDir) {
    Write-Error "Session directory not found: $SessionDir"
    exit 1
}

# Find the most recent session or look for task across all sessions
$sessions = Get-ChildItem -Path $resolvedSessionDir -Directory | Sort-Object LastWriteTime -Descending

if ($sessions.Count -eq 0) {
    Write-Error "No sessions found in: $SessionDir"
    exit 1
}

$taskFile = $null
$sessionFound = $null

foreach ($session in $sessions) {
    $tasksDir = Join-Path $session.FullName "tasks"
    if (Test-Path $tasksDir) {
        # Search for task file matching the TaskId
        $candidates = Get-ChildItem -Path $tasksDir -Filter "*.md" | Where-Object {
            $_.BaseName -match [regex]::Escape($TaskId)
        }
        if ($candidates.Count -gt 0) {
            $taskFile = $candidates[0].FullName
            $sessionFound = $session.Name
            break
        }
    }
}

if (-not $taskFile) {
    Write-Error "Task '$TaskId' not found in any session under: $SessionDir"
    exit 1
}

# Read and display the task file
$content = Get-Content -Path $taskFile -Raw

Write-Host "=== Task: $TaskId ==="  -ForegroundColor Cyan
Write-Host "Session : $sessionFound"  -ForegroundColor Gray
Write-Host "File    : $taskFile"      -ForegroundColor Gray
Write-Host ""
Write-Host $content

# Parse key fields for structured output
$statusMatch  = [regex]::Match($content, '(?m)^\*\*Status\*\*:\s*(.+)$')
$titleMatch   = [regex]::Match($content, '(?m)^#\s+(.+)$')
$priorityMatch = [regex]::Match($content, '(?m)^\*\*Priority\*\*:\s*(.+)$')

$status   = if ($statusMatch.Success)   { $statusMatch.Groups[1].Value.Trim() }   else { 'unknown' }
$title    = if ($titleMatch.Success)    { $titleMatch.Groups[1].Value.Trim() }    else { $TaskId }
$priority = if ($priorityMatch.Success) { $priorityMatch.Groups[1].Value.Trim() } else { 'normal' }

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Yellow
Write-Host "Title    : $title"
Write-Host "Status   : $status"
Write-Host "Priority : $priority"

# Return structured object for pipeline use
[PSCustomObject]@{
    TaskId   = $TaskId
    Session  = $sessionFound
    FilePath = $taskFile
    Title    = $title
    Status   = $status
    Priority = $priority
    Content  = $content
}
