#!/bin/bash
# init-session.sh
# Initializes a planning session by creating the necessary directory structure
# and session files for the planning-with-files skill.
#
# Usage: ./init-session.sh [session-name] [--force]

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_SESSIONS_DIR="${HOME}/.planning-sessions"
SESSION_VERSION="1.0.0"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DATE_SLUG="$(date +"%Y%m%d")"

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
  cat <<EOF
Usage: $(basename "$0") [SESSION_NAME] [OPTIONS]

Initialize a new planning session.

Arguments:
  SESSION_NAME   Optional name for the session (default: plan-<date>)

Options:
  --dir PATH     Base directory for sessions (default: ~/.planning-sessions)
  --force        Overwrite an existing session with the same name
  -h, --help     Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") my-feature-plan
  $(basename "$0") my-feature-plan --dir ./plans --force
EOF
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
SESSION_NAME=""
SESSIONS_DIR="$DEFAULT_SESSIONS_DIR"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --dir)
      SESSIONS_DIR="$2"
      shift 2
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -z "$SESSION_NAME" ]]; then
        SESSION_NAME="$1"
      else
        log_error "Unexpected argument: $1"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Default session name if not provided
if [[ -z "$SESSION_NAME" ]]; then
  SESSION_NAME="plan-${DATE_SLUG}"
fi

SESSION_DIR="${SESSIONS_DIR}/${SESSION_NAME}"

# ─── Pre-flight Checks ────────────────────────────────────────────────────────
if [[ -d "$SESSION_DIR" ]]; then
  if [[ "$FORCE" == true ]]; then
    log_warn "Session '${SESSION_NAME}' already exists. Overwriting (--force)."
    rm -rf "$SESSION_DIR"
  else
    log_error "Session '${SESSION_NAME}' already exists at: ${SESSION_DIR}"
    log_error "Use --force to overwrite, or choose a different name."
    exit 1
  fi
fi

# ─── Create Directory Structure ───────────────────────────────────────────────
log_info "Initializing session: ${SESSION_NAME}"
log_info "Location: ${SESSION_DIR}"

mkdir -p "${SESSION_DIR}/tasks"
mkdir -p "${SESSION_DIR}/notes"
mkdir -p "${SESSION_DIR}/artifacts"

# ─── Write session.json ───────────────────────────────────────────────────────
cat > "${SESSION_DIR}/session.json" <<EOF
{
  "version": "${SESSION_VERSION}",
  "name": "${SESSION_NAME}",
  "created_at": "${TIMESTAMP}",
  "updated_at": "${TIMESTAMP}",
  "status": "active",
  "tasks_total": 0,
  "tasks_complete": 0
}
EOF

# ─── Write PLAN.md skeleton ───────────────────────────────────────────────────
cat > "${SESSION_DIR}/PLAN.md" <<EOF
# Plan: ${SESSION_NAME}

> Created: ${TIMESTAMP}  
> Status: 🟡 In Progress

## Overview

<!-- Describe the goal of this planning session -->

## Tasks

<!-- Tasks will be tracked in the tasks/ directory -->

| ID | Title | Status |
|----|-------|--------|

## Notes

<!-- Add high-level notes here, or see notes/ directory -->

## Artifacts

<!-- Links to outputs, decisions, diagrams, etc. -->
EOF

# ─── Write .gitignore ─────────────────────────────────────────────────────────
cat > "${SESSION_DIR}/.gitignore" <<EOF
# Auto-generated lock files
*.lock
# Temporary scratch files
scratch.*
EOF

log_success "Session initialized successfully."
echo ""
echo -e "  ${CYAN}Session directory:${NC} ${SESSION_DIR}"
echo -e "  ${CYAN}Next steps:${NC}"
echo    "    1. Edit PLAN.md to describe your goal."
echo    "    2. Add task files under tasks/"
echo    "    3. Run check-complete.sh to track progress."
echo ""
