#!/bin/bash
# Shared helpers for dev-system scripts. Source, don't execute.

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

# setup_worktree <dir> <main_root>
# Copy .vscode/ai/context/ from main to worktree, then open $EDITOR for TICKET.md.
setup_worktree() {
  local dir="$1"
  local main_root="$2"

  mkdir -p "$dir/.vscode/ai/context"

  if [ -d "$main_root/.vscode/ai/context" ]; then
    cp -r "$main_root/.vscode/ai/context/"* "$dir/.vscode/ai/context/" 2>/dev/null || true
  fi

  # Ensure TICKET.md exists
  if [ ! -f "$dir/.vscode/ai/context/TICKET.md" ]; then
    cat > "$dir/.vscode/ai/context/TICKET.md" <<'EOF'
# Title

## Description

## Steps to reproduce

## Expected vs actual

## Notes
EOF
  fi

  ${EDITOR:-vim} "$dir/.vscode/ai/context/TICKET.md"
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
      "Bash(grep:*)", "Bash(find:*)", "Bash(ls:*)", "Bash(git ls-tree:*)",
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

# launch_tmux <dir> <window_name> <cmd>
# Start tmux session: detached if inside tmux, attached otherwise.
launch_tmux() {
  local dir="$1"
  local window_name="$2"
  local cmd="$3"

  if [ -n "$TMUX" ]; then
    tmux new-session -d -s "$window_name" -c "$dir" $cmd
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
