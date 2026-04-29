#!/usr/bin/env bash
# delete-session.sh - Delete a planning session and all its associated tasks
# Usage: ./delete-session.sh <session_id> [--force]

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANNING_DIR="${PLANNING_DIR:-"$(pwd)/.planning"}"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Helpers ──────────────────────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  echo "Usage: $0 <session_id> [--force]"
  echo ""
  echo "Arguments:"
  echo "  session_id   The ID of the session to delete"
  echo ""
  echo "Options:"
  echo "  --force      Skip confirmation prompt"
  echo ""
  echo "Environment:"
  echo "  PLANNING_DIR  Base directory for planning files (default: .planning)"
  exit 1
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  log_error "session_id is required."
  usage
fi

SESSION_ID="$1"
FORCE=false

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true ;;
    *) log_error "Unknown option: $1"; usage ;;
  esac
  shift
done

# ─── Validate Session ─────────────────────────────────────────────────────────
SESSION_DIR="${PLANNING_DIR}/sessions/${SESSION_ID}"
SESSION_FILE="${SESSION_DIR}/session.json"

if [[ ! -d "$SESSION_DIR" ]]; then
  log_error "Session '${SESSION_ID}' not found at: ${SESSION_DIR}"
  exit 1
fi

# ─── Gather Info Before Deletion ──────────────────────────────────────────────
TASK_COUNT=0
if [[ -d "${SESSION_DIR}/tasks" ]]; then
  TASK_COUNT=$(find "${SESSION_DIR}/tasks" -name "*.json" | wc -l | tr -d ' ')
fi

SESSION_NAME="${SESSION_ID}"
if [[ -f "$SESSION_FILE" ]] && command -v jq &>/dev/null; then
  SESSION_NAME=$(jq -r '.name // .id // empty' "$SESSION_FILE" 2>/dev/null || echo "$SESSION_ID")
fi

# ─── Confirmation ─────────────────────────────────────────────────────────────
if [[ "$FORCE" == false ]]; then
  log_warn "You are about to delete session: ${SESSION_NAME} (${SESSION_ID})"
  log_warn "This will permanently remove ${TASK_COUNT} task(s)."
  echo -e "${YELLOW}Type the session ID to confirm deletion:${NC} "
  read -r CONFIRM
  if [[ "$CONFIRM" != "$SESSION_ID" ]]; then
    log_info "Deletion cancelled."
    exit 0
  fi
fi

# ─── Delete Session ───────────────────────────────────────────────────────────
log_info "Deleting session '${SESSION_ID}' and ${TASK_COUNT} associated task(s)..."

rm -rf "$SESSION_DIR"

# Remove session from the sessions index if it exists
SESSIONS_INDEX="${PLANNING_DIR}/sessions.json"
if [[ -f "$SESSIONS_INDEX" ]] && command -v jq &>/dev/null; then
  TEMP_FILE=$(mktemp)
  jq --arg id "$SESSION_ID" 'del(.[] | select(.id == $id))' "$SESSIONS_INDEX" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$SESSIONS_INDEX"
  log_info "Removed session from sessions index."
fi

log_success "Session '${SESSION_ID}' deleted successfully."
