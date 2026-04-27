# delete-task.ps1
# Deletes a task from the planning session
# Usage: .\delete-task.ps1 -TaskId <task-id> [--force]

param(
    [Parameter(Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,

    [Parameter(Mandatory=$false)]
    [string]$SessionDir = ".codebuddy/sessions"
)

$ErrorActionPreference = "Stop"

# Find the active session
function Get-ActiveSession {
    param([string]$BaseDir)

    if (-not (Test-Path $BaseDir)) {
        Write-Error "No sessions directory found at '$BaseDir'. Run init-session first."
        exit 1
    }

    $sessions = Get-ChildItem -Path $BaseDir -Directory | Sort-Object LastWriteTime -Descending
    if ($sessions.Count -eq 0) {
        Write-Error "No active sessions found. Run init-session first."
        exit 1
    }

    return $sessions[0].FullName
}

# Load task from session
function Get-Task {
    param(
        [string]$SessionPath,
        [string]$Id
    )

    $tasksFile = Join-Path $SessionPath "tasks.json"
    if (-not (Test-Path $tasksFile)) {
        Write-Error "No tasks file found in session '$SessionPath'."
        exit 1
    }

    $tasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
    $task = $tasks | Where-Object { $_.id -eq $Id }

    if (-not $task) {
        Write-Error "Task '$Id' not found."
        exit 1
    }

    return $task, $tasks, $tasksFile
}

# Main execution
try {
    $sessionPath = Get-ActiveSession -BaseDir $SessionDir
    Write-Host "Using session: $sessionPath" -ForegroundColor Cyan

    $task, $allTasks, $tasksFile = Get-Task -SessionPath $sessionPath -Id $TaskId

    # Display task info before deletion
    Write-Host ""
    Write-Host "Task to delete:" -ForegroundColor Yellow
    Write-Host "  ID     : $($task.id)"
    Write-Host "  Title  : $($task.title)"
    Write-Host "  Status : $($task.status)"
    Write-Host ""

    # Prompt for confirmation unless --force is passed
    if (-not $Force) {
        $confirm = Read-Host "Are you sure you want to delete this task? (y/N)"
        if ($confirm -notin @('y', 'Y', 'yes', 'Yes')) {
            Write-Host "Deletion cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Filter out the task
    $updatedTasks = $allTasks | Where-Object { $_.id -ne $TaskId }

    # Save updated tasks back to file
    $updatedTasks | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksFile -Encoding UTF8

    # Also remove individual task file if it exists
    $taskFile = Join-Path $sessionPath "tasks" "$TaskId.json"
    if (Test-Path $taskFile) {
        Remove-Item $taskFile -Force
        Write-Host "Removed task file: $taskFile" -ForegroundColor Gray
    }

    Write-Host "Task '$TaskId' deleted successfully." -ForegroundColor Green

    # Update session metadata
    $metaFile = Join-Path $sessionPath "session.json"
    if (Test-Path $metaFile) {
        $meta = Get-Content $metaFile -Raw | ConvertFrom-Json
        $meta.lastModified = (Get-Date -Format "o")
        $meta.taskCount = $updatedTasks.Count
        $meta | ConvertTo-Json -Depth 5 | Set-Content -Path $metaFile -Encoding UTF8
    }

} catch {
    Write-Error "Failed to delete task: $_"
    exit 1
}
