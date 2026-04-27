#!/usr/bin/env bash
# delete-task.sh - Delete a task from the planning session
# Usage: ./delete-task.sh <session_id> <task_id> [--force]

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANNING_DIR="${PLANNING_DIR:-$HOME/.planning-with-files}"

# ── Helpers ──────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") <session_id> <task_id> [--force]

Arguments:
  session_id   The planning session identifier
  task_id      The task identifier to delete

Options:
  --force      Skip confirmation prompt
  -h, --help   Show this help message

Examples:
  $(basename "$0") session-2024-01-15 task-3
  $(basename "$0") session-2024-01-15 task-3 --force
EOF
}

error() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "INFO: $*"
}

# ── Argument parsing ─────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done

SESSION_ID="$1"
TASK_ID="$2"
FORCE=false

if [[ "${3:-}" == "--force" ]]; then
  FORCE=true
fi

# ── Resolve paths ────────────────────────────────────────────────────────────
SESSION_DIR="$PLANNING_DIR/$SESSION_ID"
TASKS_DIR="$SESSION_DIR/tasks"
TASK_FILE="$TASKS_DIR/${TASK_ID}.json"
SESSION_FILE="$SESSION_DIR/session.json"

[[ -d "$SESSION_DIR" ]]  || error "Session '$SESSION_ID' not found at $SESSION_DIR"
[[ -d "$TASKS_DIR" ]]    || error "Tasks directory missing for session '$SESSION_ID'"
[[ -f "$TASK_FILE" ]]    || error "Task '$TASK_ID' not found in session '$SESSION_ID'"
[[ -f "$SESSION_FILE" ]] || error "Session file missing for session '$SESSION_ID'"

# ── Read task details for confirmation ───────────────────────────────────────
if command -v jq &>/dev/null; then
  TASK_TITLE=$(jq -r '.title // .id' "$TASK_FILE")
  TASK_STATUS=$(jq -r '.status // "unknown"' "$TASK_FILE")
else
  TASK_TITLE="$TASK_ID"
  TASK_STATUS="unknown"
fi

# ── Confirmation prompt ───────────────────────────────────────────────────────
if [[ "$FORCE" == false ]]; then
  echo "You are about to delete the following task:"
  echo "  Session : $SESSION_ID"
  echo "  Task ID : $TASK_ID"
  echo "  Title   : $TASK_TITLE"
  echo "  Status  : $TASK_STATUS"
  echo ""
  read -r -p "Are you sure? [y/N] " CONFIRM
  case "$CONFIRM" in
    [yY][eE][sS]|[yY]) ;;
    *) info "Deletion cancelled."; exit 0 ;;
  esac
fi

# ── Delete the task file ──────────────────────────────────────────────────────
rm -f "$TASK_FILE"
info "Deleted task file: $TASK_FILE"

# ── Update session.json task list ────────────────────────────────────────────
if command -v jq &>/dev/null; then
  UPDATED_SESSION=$(jq \
    --arg tid "$TASK_ID" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '.tasks = [.tasks[]? | select(. != $tid)]
     | .updated_at = $ts
     | .task_count = (.tasks | length)' \
    "$SESSION_FILE")
  echo "$UPDATED_SESSION" > "$SESSION_FILE"
  info "Updated session manifest."
else
  # Fallback: sed-based removal of task id reference
  sed -i "/$TASK_ID/d" "$SESSION_FILE" 2>/dev/null || true
  info "Updated session manifest (sed fallback)."
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo "Task '$TASK_ID' successfully deleted from session '$SESSION_ID'."
