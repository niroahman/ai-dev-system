#!/bin/bash
# Shared helpers for dev-system scripts. Source, don't execute.

# Load model config (config.local overrides config)
_DEVSYS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config
[ -f "$_DEVSYS_ROOT/config" ]       && source "$_DEVSYS_ROOT/config"
[ -f "$_DEVSYS_ROOT/config.local" ] && source "$_DEVSYS_ROOT/config.local"

# resolve_role <agent>
# Sets globals: ROLE_NAME, ROLE_PORTRAIT_MD
resolve_role() {
  local agent="$1"
  case "$agent" in
    claude)  ROLE_NAME="Pat" ;;
    gemini)  ROLE_NAME="Mat" ;;
    *)       ROLE_NAME="$agent" ;;
  esac

  local lower
  lower=$(echo "$ROLE_NAME" | tr '[:upper:]' '[:lower:]')
  local portrait_path="$HOME/dev-system/portraits/${lower}.png"

  if [ -s "$portrait_path" ]; then
    ROLE_PORTRAIT_MD="<img src=\"${lower}.png\" width=\"180\" align=\"right\" />"
  else
    ROLE_PORTRAIT_MD="**$ROLE_NAME**"
  fi
}

# resolve_named_role <name>
# Like resolve_role but takes the role name directly (Nikke, Poirot, etc.)
resolve_named_role() {
  ROLE_NAME="$1"
  local lower
  lower=$(echo "$ROLE_NAME" | tr '[:upper:]' '[:lower:]')
  local portrait_path="$HOME/dev-system/portraits/${lower}.png"

  if [ -s "$portrait_path" ]; then
    ROLE_PORTRAIT_MD="<img src=\"${lower}.png\" width=\"180\" align=\"right\" />"
  else
    ROLE_PORTRAIT_MD="**$ROLE_NAME**"
  fi
}

# setup_worktree <dir> <main_root> [--no-editor]
# Copy .ai-team/ from main to worktree, optionally open $EDITOR for TICKET.md.
setup_worktree() {
  local dir="$1"
  local main_root="$2"
  local no_editor="${3:-}"

  mkdir -p "$dir/.ai-team/context"

  if [ -d "$main_root/.ai-team/context" ]; then
    cp -r "$main_root/.ai-team/context/"* "$dir/.ai-team/context/" 2>/dev/null || true
  fi
  # WATSON_MAP.md travels with context — agent output files do NOT
  [ -f "$main_root/.ai-team/WATSON_MAP.md" ] && \
    cp "$main_root/.ai-team/WATSON_MAP.md" "$dir/.ai-team/WATSON_MAP.md" 2>/dev/null || true
  # Remove any stale agent output files that may have been copied
  rm -f "$dir/.ai-team/INVESTIGATION.md" \
        "$dir/.ai-team/REVIEW.md" \
        "$dir/.ai-team/FIX-SUMMARY.md" \
        "$dir/.ai-team/BLOCKED.md"

  # Ensure TICKET.md exists
  if [ ! -f "$dir/.ai-team/context/TICKET.md" ]; then
    cat > "$dir/.ai-team/context/TICKET.md" <<'EOF'
# Title

## Description

## Steps to reproduce

## Expected vs actual

## Notes
EOF
  fi

  [ "$no_editor" != "--no-editor" ] && ${EDITOR:-vim} "$dir/.ai-team/context/TICKET.md"
}

# kill_role_session <role>
# Kill tmux sessions for a role. Frees the role for new work.
kill_role_session() {
  local role="$1"
  local role_cap
  role_cap="$(echo "${role:0:1}" | tr '[:lower:]' '[:upper:]')${role:1}"

  if [ -n "$TMUX" ]; then
    tmux list-sessions -F "#{session_name}" 2>/dev/null \
      | grep -i "^${role_cap}-" \
      | while read -r s; do
          tmux kill-session -t "$s" 2>/dev/null || true
        done
  fi
}

# find_continue_wt
# Finds and claims the most recent worktree to continue in.
# Priority: Nikke → Watson → (empty)
# Frees the previous owner (clears tracking, kills session).
# Outputs path or empty string.
find_continue_wt() {
  for role in nikke watson; do
    local tracking="$HOME/.${role}_last_worktree"
    if [ -f "$tracking" ]; then
      local d
      d=$(cat "$tracking")
      if [ -d "$d" ]; then
        # Free the previous owner
        rm -f "$tracking"
        kill_role_session "$role"
        echo "$d"
        return
      fi
    fi
  done
  echo ""
}

# run_watson_inline <dir>
# Run Watson synchronously in the given worktree directory.
# Delegates to watson --inline to avoid prompt duplication.
run_watson_inline() {
  local dir="$1"
  watson --inline "$dir"
}

# write_claude_settings <dir>
# Write .claude/settings.json with safe-tools permissions.
write_claude_settings() {
  local dir="$1"
  mkdir -p "$dir/.claude"
  cat > "$dir/.claude/settings.json" <<'EOF'
{
  "permissions": {
    "allow": [
      "Read", "Write", "Edit", "Glob", "Grep",
      "AskUserQuestion",
      "EnterPlanMode", "ExitPlanMode",
      "TaskCreate", "TaskList", "TaskGet", "TaskUpdate", "TaskOutput", "TaskStop",
      "Bash(grep:*)", "Bash(find:*)", "Bash(ls:*)", "Bash(git ls-tree:*)", "Bash(poirot:*)", "Bash(python3:*)",
      "mcp__safe-tools__run_tests",
      "mcp__safe-tools__run_install",
      "mcp__safe-tools__run_linter",
      "mcp__safe-tools__git_status",
      "mcp__safe-tools__git_log",
      "mcp__safe-tools__git_diff",
      "mcp__safe-tools__git_commit",
      "mcp__safe-tools__list_dir",
      "mcp__safe-tools__check_tool"
    ]
  }
}
EOF
}

# wait_for_agent <session_prefix> <output_file>
# Block until output_file exists OR tmux session is gone.
# For pat/mat also watches tracking file cleared.
wait_for_agent() {
  local prefix="$1"
  local output_file="${2:-}"
  local role
  role=$(echo "$prefix" | tr '[:upper:]' '[:lower:]')
  local tracking="$HOME/.${role}_last_worktree"
  [ -z "$TMUX" ] && return
  printf "⏳  Waiting for \033[1;36m%s\033[0m to finish...\n" "$prefix"
  while true; do
    # Done if output file written — wait 5s for final flush before killing
    [ -n "$output_file" ] && [ -f "$output_file" ] && {
      # Wait until file stops growing (agent finished writing)
      local _prev_size=0 _curr_size
      while true; do
        _curr_size=$(wc -c < "$output_file" 2>/dev/null || echo 0)
        [ "$_curr_size" -eq "$_prev_size" ] && [ "$_curr_size" -gt 0 ] && break
        _prev_size=$_curr_size
        sleep 2
      done
      sleep 3
      local _sess
      _sess=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -i "^${prefix}-" | head -1)
      [ -n "$_sess" ] && tmux kill-session -t "$_sess" 2>/dev/null || true
      rm -f "$HOME/.${role}_last_worktree"
      break
    }
    # Done if tmux session gone
    tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -qi "^${prefix}-" || break
    # pat/mat: tracking file cleared means done
    if [ "$role" = "pat" ] || [ "$role" = "mat" ]; then
      [ ! -f "$tracking" ] && break
    fi
    sleep 3
  done
}

# launch_tmux <dir> <window_name> <cmd>
# Start tmux session: detached if inside tmux, attached otherwise.
launch_tmux() {
  local dir="$1"
  local window_name="$2"
  local cmd="$3"

  # Kill any stale session with same name (from aborted runs)
  tmux kill-session -t "$window_name" 2>/dev/null || true

  if [ -n "$TMUX" ]; then
    tmux new-session -d -s "$window_name" -c "$dir" \
      bash -c "$cmd; tmux kill-session -t \"$window_name\" 2>/dev/null || true"
    printf "🪟  Session \033[1;33m%s\033[0m started\n" "$window_name"
  else
    tmux new-session -s "$window_name" -c "$dir" $cmd
  fi
}

# track_worktree <role> <dir>
# Save worktree path for role tracking.
track_worktree() {
  local role="$1"
  local dir="$2"
  echo "$dir" > "$HOME/.${role}_last_worktree"
}
