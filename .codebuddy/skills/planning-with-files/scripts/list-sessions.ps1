# list-sessions.ps1
# Lists all planning sessions in the sessions directory
# Usage: .\list-sessions.ps1 [-SessionsDir <path>] [-Format <table|json|simple>] [-Filter <active|completed|all>]

param(
    [string]$SessionsDir = ".planning",
    [ValidateSet("table", "json", "simple")]
    [string]$Format = "table",
    [ValidateSet("active", "completed", "all")]
    [string]$Filter = "all"
)

$ErrorActionPreference = "Stop"

# Resolve sessions directory
$SessionsPath = Join-Path (Get-Location) $SessionsDir

if (-not (Test-Path $SessionsPath)) {
    Write-Error "Sessions directory not found: $SessionsPath"
    exit 1
}

# Collect session data
$Sessions = @()

Get-ChildItem -Path $SessionsPath -Directory | ForEach-Object {
    $SessionDir = $_.FullName
    $SessionId = $_.Name
    $MetaFile = Join-Path $SessionDir "session.json"

    if (-not (Test-Path $MetaFile)) {
        return
    }

    try {
        $Meta = Get-Content $MetaFile -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse session metadata for '$SessionId': $_"
        return
    }

    # Count tasks by status
    $TasksDir = Join-Path $SessionDir "tasks"
    $TotalTasks = 0
    $CompletedTasks = 0
    $PendingTasks = 0
    $InProgressTasks = 0

    if (Test-Path $TasksDir) {
        Get-ChildItem -Path $TasksDir -Filter "*.json" | ForEach-Object {
            try {
                $Task = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $TotalTasks++
                switch ($Task.status) {
                    "completed"   { $CompletedTasks++ }
                    "in-progress" { $InProgressTasks++ }
                    default       { $PendingTasks++ }
                }
            } catch {
                # skip malformed task files
            }
        }
    }

    $IsComplete = ($TotalTasks -gt 0) -and ($CompletedTasks -eq $TotalTasks)
    $StatusLabel = if ($IsComplete) { "completed" } else { "active" }

    # Apply filter
    if ($Filter -ne "all" -and $StatusLabel -ne $Filter) {
        return
    }

    $Sessions += [PSCustomObject]@{
        Id          = $SessionId
        Name        = if ($Meta.name) { $Meta.name } else { $SessionId }
        Status      = $StatusLabel
        Created     = if ($Meta.created_at) { $Meta.created_at } else { "unknown" }
        Total       = $TotalTasks
        Completed   = $CompletedTasks
        InProgress  = $InProgressTasks
        Pending     = $PendingTasks
        Progress    = if ($TotalTasks -gt 0) { [math]::Round(($CompletedTasks / $TotalTasks) * 100) } else { 0 }
    }
}

if ($Sessions.Count -eq 0) {
    Write-Host "No sessions found matching filter: '$Filter'" -ForegroundColor Yellow
    exit 0
}

# Output in requested format
switch ($Format) {
    "json" {
        $Sessions | ConvertTo-Json -Depth 5
    }

    "simple" {
        $Sessions | ForEach-Object {
            Write-Host "$($_.Id)  [$($_.Status)]  $($_.Name)  ($($_.Completed)/$($_.Total) tasks)"
        }
    }

    "table" {
        $Header = "{0,-36}  {1,-20}  {2,-10}  {3,-8}  {4,-10}  {5,-10}  {6,-10}  {7,-8}" -f \
            "ID", "Name", "Status", "Progress", "Total", "Done", "In-Prog", "Pending"
        $Divider = "-" * ($Header.Length)

        Write-Host ""
        Write-Host $Header -ForegroundColor Cyan
        Write-Host $Divider

        $Sessions | ForEach-Object {
            $StatusColor = if ($_.Status -eq "completed") { "Green" } else { "Yellow" }
            $ProgressStr = "$($_.Progress)%"
            $Line = "{0,-36}  {1,-20}  {2,-10}  {3,-8}  {4,-10}  {5,-10}  {6,-10}  {7,-8}" -f \
                $_.Id, $_.Name, $_.Status, $ProgressStr, $_.Total, $_.Completed, $_.InProgress, $_.Pending
            Write-Host $Line -ForegroundColor $StatusColor
        }

        Write-Host $Divider
        Write-Host "Total sessions: $($Sessions.Count)" -ForegroundColor Cyan
        Write-Host ""
    }
}
