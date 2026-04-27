#!/usr/bin/env bash
# list-tasks.sh — List all tasks and their statuses from the current planning session
# Usage: ./list-tasks.sh [--filter <status>] [--session <session-dir>]
#
# Options:
#   --filter <status>   Filter tasks by status: pending, in-progress, complete, blocked
#   --session <dir>     Path to session directory (default: ./.planning-session)

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
SESSION_DIR="./.planning-session"
FILTER=""

# ─── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTER="$2"
      shift 2
      ;;
    --session)
      SESSION_DIR="$2"
      shift 2
      ;;
    -h|--help)
      head -6 "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ─── Validate session directory ──────────────────────────────────────────────
if [[ ! -d "$SESSION_DIR" ]]; then
  echo -e "${RED}Error:${NC} Session directory not found: $SESSION_DIR"
  echo "Run init-session.sh first to create a planning session."
  exit 1
fi

TASKS_DIR="$SESSION_DIR/tasks"
if [[ ! -d "$TASKS_DIR" ]]; then
  echo -e "${YELLOW}No tasks directory found in session.${NC}"
  exit 0
fi

# ─── Status helpers ──────────────────────────────────────────────────────────
status_colour() {
  case "$1" in
    complete)    echo -e "${GREEN}" ;;
    in-progress) echo -e "${CYAN}" ;;
    blocked)     echo -e "${RED}" ;;
    pending)     echo -e "${YELLOW}" ;;
    *)           echo -e "${GRAY}" ;;
  esac
}

status_icon() {
  case "$1" in
    complete)    echo "✔" ;;
    in-progress) echo "▶" ;;
    blocked)     echo "✖" ;;
    pending)     echo "○" ;;
    *)           echo "?" ;;
  esac
}

# ─── Collect tasks ───────────────────────────────────────────────────────────
declare -A STATUS_COUNT=( [pending]=0 [in-progress]=0 [complete]=0 [blocked]=0 [unknown]=0 )
TOTAL=0
PRINTED=0

echo -e "\n${BOLD}Planning Session Tasks${NC}  ${GRAY}(${SESSION_DIR})${NC}\n"
printf "%-6s %-20s %-14s %s\n" "ID" "STATUS" "UPDATED" "TITLE"
printf '%0.s─' {1..70}; echo

while IFS= read -r -d '' task_file; do
  TOTAL=$(( TOTAL + 1 ))

  # Extract fields from the task file (YAML-ish front-matter or plain key: value)
  task_id=$(basename "$(dirname "$task_file")")
  title=$(grep -m1 '^title:' "$task_file" 2>/dev/null | sed 's/^title:[[:space:]]*//' || echo "(untitled)")
  status=$(grep -m1 '^status:' "$task_file" 2>/dev/null | sed 's/^status:[[:space:]]*//' || echo "unknown")
  updated=$(grep -m1 '^updated:' "$task_file" 2>/dev/null | sed 's/^updated:[[:space:]]*//' || echo "-")

  # Normalise status key for counting
  count_key="$status"
  [[ -z "${STATUS_COUNT[$count_key]+_}" ]] && count_key="unknown"
  STATUS_COUNT[$count_key]=$(( STATUS_COUNT[$count_key] + 1 ))

  # Apply filter
  if [[ -n "$FILTER" && "$status" != "$FILTER" ]]; then
    continue
  fi

  PRINTED=$(( PRINTED + 1 ))
  col=$(status_colour "$status")
  icon=$(status_icon "$status")
  printf "${col}%-6s %-20s${NC} %-14s %s\n" \
    "$task_id" \
    "$icon $status" \
    "$updated" \
    "$title"
done < <(find "$TASKS_DIR" -name 'task.md' -print0 | sort -z)

# ─── Summary ─────────────────────────────────────────────────────────────────
printf '%0.s─' {1..70}; echo
echo -e "\n${BOLD}Summary:${NC}  Total: $TOTAL  |  "\
"${GREEN}Complete: ${STATUS_COUNT[complete]}${NC}  "\
"${CYAN}In-Progress: ${STATUS_COUNT[in-progress]}${NC}  "\
"${YELLOW}Pending: ${STATUS_COUNT[pending]}${NC}  "\
"${RED}Blocked: ${STATUS_COUNT[blocked]}${NC}"

if [[ -n "$FILTER" ]]; then
  echo -e "${GRAY}Filtered by status '${FILTER}': showing ${PRINTED} of ${TOTAL} tasks.${NC}"
fi

echo
