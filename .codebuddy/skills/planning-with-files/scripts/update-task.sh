#!/usr/bin/env bash
# update-task.sh — Update the status of a task in the active planning session
# Usage: ./update-task.sh <task-id> <status> [notes]
#   task-id : The identifier of the task (e.g., TASK-001)
#   status  : One of: todo | in-progress | done | blocked | skipped
#   notes   : Optional free-text notes to append to the task entry

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
VALID_STATUSES=("todo" "in-progress" "done" "blocked" "skipped")
SESSION_DIR="${PLANNING_SESSION_DIR:-.planning-session}"
TASKS_FILE="${SESSION_DIR}/tasks.md"
LOG_FILE="${SESSION_DIR}/session.log"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() {
  local level="$1"
  shift
  local msg="$*"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[${ts}] [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

die() {
  log "ERROR" "$*"
  exit 1
}

usage() {
  echo "Usage: $0 <task-id> <status> [notes]"
  echo "  status must be one of: ${VALID_STATUSES[*]}"
  exit 1
}

is_valid_status() {
  local candidate="$1"
  for s in "${VALID_STATUSES[@]}"; do
    [[ "${s}" == "${candidate}" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
[[ $# -lt 2 ]] && usage

TASK_ID="$1"
NEW_STATUS="$2"
NOTES="${3:-}"

is_valid_status "${NEW_STATUS}" || die "Invalid status '${NEW_STATUS}'. Must be one of: ${VALID_STATUSES[*]}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
[[ -d "${SESSION_DIR}" ]] || die "No active planning session found at '${SESSION_DIR}'. Run init-session.sh first."
[[ -f "${TASKS_FILE}" ]] || die "Tasks file not found: ${TASKS_FILE}"

# Verify the task ID exists in the file
if ! grep -qE "^\|[[:space:]]*${TASK_ID}[[:space:]]*\|" "${TASKS_FILE}"; then
  die "Task '${TASK_ID}' not found in ${TASKS_FILE}"
fi

# ---------------------------------------------------------------------------
# Status icon mapping
# ---------------------------------------------------------------------------
status_icon() {
  case "$1" in
    todo)        echo "⬜" ;;
    in-progress) echo "🔄" ;;
    done)        echo "✅" ;;
    blocked)     echo "🚫" ;;
    skipped)     echo "⏭️" ;;
    *)           echo "❓" ;;
  esac
}

ICON=$(status_icon "${NEW_STATUS}")

# ---------------------------------------------------------------------------
# Update the task row in tasks.md
# Using sed to replace the status column in the matching row.
# Expected table format (pipe-delimited):
#   | TASK-001 | Short description | todo | ... |
# The status is assumed to be the 3rd column (index 2, 0-based).
# ---------------------------------------------------------------------------
TMP_FILE="$(mktemp)"

awk -v task_id="${TASK_ID}" \
    -v new_status="${NEW_STATUS}" \
    -v icon="${ICON}" \
    -v notes="${NOTES}" \
'BEGIN { FS="|"; OFS="|" }
/^\|/ {
  # Trim leading/trailing whitespace from first data column
  id = $2
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
  if (id == task_id) {
    $4 = " " icon " " new_status " "
    if (notes != "") {
      # Append notes to the last notes column (assumed col 6)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $6)
      if ($6 == "") {
        $6 = " " notes " "
      } else {
        $6 = " " $6 "; " notes " "
      }
    }
    print
    next
  }
}
{ print }
' "${TASKS_FILE}" > "${TMP_FILE}"

mv "${TMP_FILE}" "${TASKS_FILE}"

# ---------------------------------------------------------------------------
# Record the change in the session log
# ---------------------------------------------------------------------------
log "INFO" "Task '${TASK_ID}' updated to '${NEW_STATUS}'${NOTES:+ — notes: ${NOTES}}"

echo "✔ Task '${TASK_ID}' is now '${ICON} ${NEW_STATUS}'."
