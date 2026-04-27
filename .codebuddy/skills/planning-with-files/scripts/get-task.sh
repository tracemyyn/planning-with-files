#!/bin/bash
# get-task.sh - Retrieve details of a specific task from the planning session
# Usage: ./get-task.sh <task-id> [session-dir]

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
DEFAULT_SESSION_DIR=".planning"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Helpers ─────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $(basename "$0") <task-id> [session-dir]"
  echo ""
  echo "Arguments:"
  echo "  task-id      The unique identifier of the task (e.g. TASK-001)"
  echo "  session-dir  Directory where planning files are stored (default: .planning)"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") TASK-001"
  echo "  $(basename "$0") TASK-003 .my-planning"
  exit 1
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "[INFO] $*"
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  usage
fi

TASK_ID="$1"
SESSION_DIR="${2:-$DEFAULT_SESSION_DIR}"

# ─── Validate Session Directory ───────────────────────────────────────────────
if [[ ! -d "$SESSION_DIR" ]]; then
  error "Session directory '$SESSION_DIR' does not exist. Run init-session.sh first."
fi

TASKS_DIR="$SESSION_DIR/tasks"
if [[ ! -d "$TASKS_DIR" ]]; then
  error "Tasks directory '$TASKS_DIR' not found. Session may be corrupted."
fi

# ─── Locate Task File ─────────────────────────────────────────────────────────
# Task files are stored as <TASK_ID>.md (case-insensitive search)
TASK_FILE=""
for f in "$TASKS_DIR"/*.md; do
  [[ -f "$f" ]] || continue
  basename_no_ext="$(basename "$f" .md)"
  if [[ "${basename_no_ext^^}" == "${TASK_ID^^}" ]]; then
    TASK_FILE="$f"
    break
  fi
done

if [[ -z "$TASK_FILE" ]]; then
  error "Task '$TASK_ID' not found in '$TASKS_DIR'."
fi

# ─── Parse and Display Task ───────────────────────────────────────────────────
info "Task details for: $TASK_ID"
echo "────────────────────────────────────────────────────────────"

# Extract key fields using grep/sed for portability
extract_field() {
  local field="$1"
  local file="$2"
  grep -i "^\*\*${field}\*\*" "$file" | sed 's/.*\*\*[^*]*\*\*[[:space:]]*:[[:space:]]*//' | head -1
}

TITLE=$(grep -m1 '^# ' "$TASK_FILE" | sed 's/^# //' || echo "(no title)")
STATUS=$(extract_field "Status" "$TASK_FILE")
PRIORITY=$(extract_field "Priority" "$TASK_FILE")
ASSIGNEE=$(extract_field "Assignee" "$TASK_FILE")
CREATED=$(extract_field "Created" "$TASK_FILE")
UPDATED=$(extract_field "Updated" "$TASK_FILE")

echo "ID       : $TASK_ID"
echo "Title    : ${TITLE}"
echo "Status   : ${STATUS:-unknown}"
echo "Priority : ${PRIORITY:-normal}"
echo "Assignee : ${ASSIGNEE:-(unassigned)}"
echo "Created  : ${CREATED:-(unknown)}"
echo "Updated  : ${UPDATED:-(unknown)}"
echo "File     : $TASK_FILE"
echo "────────────────────────────────────────────────────────────"

# ─── Print Full Task Content ──────────────────────────────────────────────────
echo ""
echo "Full content:"
echo ""
cat "$TASK_FILE"

exit 0
