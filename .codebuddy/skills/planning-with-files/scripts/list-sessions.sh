#!/bin/bash
# list-sessions.sh - List all planning sessions
# Usage: ./list-sessions.sh [--format=table|json|plain] [--status=active|archived|all]

set -euo pipefail

# Default configuration
PLANNING_DIR="${PLANNING_DIR:-.planning}"
FORMAT="table"
STATUS_FILTER="all"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --format=*)
      FORMAT="${arg#*=}"
      ;;
    --status=*)
      STATUS_FILTER="${arg#*=}"
      ;;
    --help|-h)
      echo "Usage: $0 [--format=table|json|plain] [--status=active|archived|all]"
      echo ""
      echo "Options:"
      echo "  --format    Output format: table (default), json, or plain"
      echo "  --status    Filter by status: active, archived, or all (default)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Validate format
if [[ ! "$FORMAT" =~ ^(table|json|plain)$ ]]; then
  echo "Error: Invalid format '$FORMAT'. Must be table, json, or plain." >&2
  exit 1
fi

# Check if planning directory exists
if [[ ! -d "$PLANNING_DIR" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo '{"sessions": [], "total": 0}'
  else
    echo "No planning sessions found. Run init-session.sh to create one."
  fi
  exit 0
fi

# Collect session data
SESSIONS=()
SESSION_DIRS=()

for session_dir in "$PLANNING_DIR"/*/; do
  [[ -d "$session_dir" ]] || continue
  meta_file="$session_dir/meta.json"
  [[ -f "$meta_file" ]] || continue

  session_id=$(basename "$session_dir")
  created=$(python3 -c "import json,sys; d=json.load(open('$meta_file')); print(d.get('created','unknown'))" 2>/dev/null || echo "unknown")
  title=$(python3 -c "import json,sys; d=json.load(open('$meta_file')); print(d.get('title','Untitled'))" 2>/dev/null || echo "Untitled")
  status=$(python3 -c "import json,sys; d=json.load(open('$meta_file')); print(d.get('status','active'))" 2>/dev/null || echo "active")

  # Apply status filter
  if [[ "$STATUS_FILTER" != "all" && "$status" != "$STATUS_FILTER" ]]; then
    continue
  fi

  # Count tasks
  task_count=0
  completed_count=0
  if [[ -d "$session_dir/tasks" ]]; then
    task_count=$(find "$session_dir/tasks" -name "*.json" | wc -l | tr -d ' ')
    completed_count=$(grep -rl '"status": "done"' "$session_dir/tasks" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  fi

  SESSIONS+=("$session_id|$title|$status|$created|$task_count|$completed_count")
done

TOTAL=${#SESSIONS[@]}

# Output results
if [[ "$FORMAT" == "json" ]]; then
  echo '{"sessions": ['
  for i in "${!SESSIONS[@]}"; do
    IFS='|' read -r sid stitle sstatus screated stasks scompleted <<< "${SESSIONS[$i]}"
    comma=","
    [[ $i -eq $((TOTAL - 1)) ]] && comma=""
    printf '  {"id": "%s", "title": "%s", "status": "%s", "created": "%s", "tasks": %s, "completed": %s}%s\n' \
      "$sid" "$stitle" "$sstatus" "$screated" "$stasks" "$scompleted" "$comma"
  done
  echo '], "total": '$TOTAL'}'

elif [[ "$FORMAT" == "plain" ]]; then
  for entry in "${SESSIONS[@]}"; do
    IFS='|' read -r sid stitle sstatus screated stasks scompleted <<< "$entry"
    echo "$sid  $stitle  [$sstatus]  $screated  tasks:$stasks  done:$scompleted"
  done
  echo "Total: $TOTAL session(s)"

else
  # Table format
  printf '\n%-20s %-30s %-10s %-20s %s\n' "SESSION ID" "TITLE" "STATUS" "CREATED" "TASKS"
  printf '%s\n' "$(printf '%.0s-' {1..90})"
  if [[ $TOTAL -eq 0 ]]; then
    echo "  No sessions found."
  else
    for entry in "${SESSIONS[@]}"; do
      IFS='|' read -r sid stitle sstatus screated stasks scompleted <<< "$entry"
      printf '%-20s %-30s %-10s %-20s %s/%s\n' \
        "$sid" "${stitle:0:29}" "$sstatus" "${screated:0:19}" "$scompleted" "$stasks"
    done
  fi
  printf '\nTotal: %d session(s)\n\n' "$TOTAL"
fi
