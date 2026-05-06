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
    ROLE_PORTRAIT_MD="<img src=\".vscode/ai/${lower}.png\" width=\"120\" align=\"right\" />"
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
    ROLE_PORTRAIT_MD="<img src=\".vscode/ai/${lower}.png\" width=\"120\" align=\"right\" />"
  else
    ROLE_PORTRAIT_MD="**$ROLE_NAME**"
  fi
}
