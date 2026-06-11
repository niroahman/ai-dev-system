#!/bin/bash
# install.sh — run after cloning the repo on a new machine
# Idempotent: safe to re-run after pulling updates
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_FZF=0
NON_INTERACTIVE=0
for arg in "$@"; do
  case "$arg" in
    --skip-fzf) SKIP_FZF=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
  esac
done

# --- Interactive configuration ---
CONFIG_LOCAL="$REPO_DIR/config.local"
if [ "$NON_INTERACTIVE" = 0 ]; then
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║  dev-system setup                    ║"
  echo "╚══════════════════════════════════════╝"
  echo ""

  # Paths from existing config.local if present, else defaults
  _existing_work=""
  _existing_personal=""
  [ -f "$CONFIG_LOCAL" ] && source "$CONFIG_LOCAL"
  [ -n "$WORK_DIR" ] && _existing_work="$WORK_DIR"
  [ -n "$PERSONAL_DIR" ] && _existing_personal="$PERSONAL_DIR"

  echo "Paths are used by detect-stack to choose _work vs _personal skills."
  echo "Leave empty for defaults."
  echo ""

  read -r -p "Work repos path [${_existing_work:-$HOME/work}]: " input_work
  read -r -p "Personal repos path [${_existing_personal:-$HOME/personal}]: " input_personal

  WORK_DIR="${input_work:-${_existing_work:-$HOME/work}}"
  PERSONAL_DIR="${input_personal:-${_existing_personal:-$HOME/personal}}"

  # Write config.local
  {
    echo "# dev-system local configuration"
    echo "# Written by install.sh $(date -I)"
    echo ""
    echo "# Paths for detect-stack (_work vs _personal routing)"
    echo "WORK_DIR=\"$WORK_DIR\""
    echo "PERSONAL_DIR=\"$PERSONAL_DIR\""
    echo ""
  } > "$CONFIG_LOCAL"
  echo "  ✓ Written $CONFIG_LOCAL"

  # Append model overrides from current config if they exist
  if [ -f "$REPO_DIR/config" ]; then
    # shellcheck source=../config
    source "$REPO_DIR/config"
    for var in MODEL_WATSON MODEL_PAT MODEL_NIKKE MODEL_POIROT MODEL_MAT MODEL_WATSON_GEMINI; do
      [ -n "${!var}" ] && echo "${var}=\"${!var}\"" 2>/dev/null >> "$CONFIG_LOCAL"
    done
    # Remove any config.local-only model vars sourced from a previous install
  fi

  echo ""
fi

# Ensure dev-system directory
mkdir -p "$HOME/dev-system"
echo "Installing dev-system from $REPO_DIR → $HOME/dev-system/"

# 1. Symlink the repo's bin/ skills/ prompts/ portraits/ into ~/dev-system/
ln -snf "$REPO_DIR/bin"        "$HOME/dev-system/bin"
ln -snf "$REPO_DIR/skills"     "$HOME/dev-system/skills"
ln -snf "$REPO_DIR/prompts"    "$HOME/dev-system/prompts"
ln -snf "$REPO_DIR/portraits"  "$HOME/dev-system/portraits"

# 2. Symlink global Claude/Gemini configs (back up existing if not symlinks)
mkdir -p "$HOME/.claude" "$HOME/.gemini"

for pair in "claude/CLAUDE.md:.claude/CLAUDE.md" "gemini/GEMINI.md:.gemini/GEMINI.md"; do
  src="${pair%%:*}"
  dst="${pair##*:}"
  full_dst="$HOME/$dst"

  if [ -e "$full_dst" ] && [ ! -L "$full_dst" ]; then
    mv "$full_dst" "$full_dst.bak.$(date +%s)"
    echo "Backed up existing $dst"
  fi
  ln -snf "$REPO_DIR/$src" "$full_dst"
done

# 3. PATH update (if not already present in zshrc)
if ! grep -q 'dev-system/bin' "$HOME/.zshrc" 2>/dev/null; then
  echo '' >> "$HOME/.zshrc"
  echo '# Personal AI dev system' >> "$HOME/.zshrc"
  echo 'export PATH="$HOME/dev-system/bin:$PATH"' >> "$HOME/.zshrc"
  echo "Added bin to PATH in ~/.zshrc — restart shell or 'source ~/.zshrc'"
fi

# 4. Global gitignore for worktree artifacts
GIG="$HOME/.gitignore_global"
touch "$GIG"
for entry in ".vscode/ai/" ".agent-context.md" ".agent-task.md" ".investigate-prompt.md" ".ticket/" "INVESTIGATION.md" "REVIEW.md" ".ai-team/" "WATSON_MAP.md"; do
  grep -qxF "$entry" "$GIG" || echo "$entry" >> "$GIG"
done
git config --global core.excludesfile "$GIG"

# 5. Global git hook: strip AI co-authorship from commits
mkdir -p "$REPO_DIR/git-hooks"
cat > "$REPO_DIR/git-hooks/commit-msg" <<'HOOK'
#!/bin/bash
sed -i '' '/^Co-Authored-By:.*[Cc]laude/d;/^Co-Authored-By:.*[Aa]nthropicr/d;/^Co-Authored-By:.*[Gg]emini/d;/^Co-Authored-By:.*[Cc]opilot/d' "$1"
HOOK
chmod +x "$REPO_DIR/git-hooks/commit-msg"
git config --global core.hooksPath "$REPO_DIR/git-hooks"

# 6. Make scripts executable (in case clone didn't preserve)
chmod +x "$REPO_DIR/bin/"* 2>/dev/null || true

# 7. Install fzf (required by ai-team menu)
if [ "$SKIP_FZF" = 1 ]; then
  echo "  — fzf (skipped)"
elif command -v fzf >/dev/null; then
  echo "  ✓ fzf"
else
  echo "  Installing fzf (required by ai-team)..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew >/dev/null; then
      brew install fzf
    else
      echo "  ✗ Homebrew not found — install fzf manually: brew install fzf"
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get >/dev/null; then
      sudo apt-get update -qq && sudo apt-get install -y -qq fzf
    elif command -v pacman >/dev/null; then
      sudo pacman -S --noconfirm fzf
    elif command -v dnf >/dev/null; then
      sudo dnf install -y fzf
    else
      echo "  ✗ Package manager not detected — install fzf manually:"
      echo "     Debian/Ubuntu: sudo apt install fzf"
      echo "     Arch:          sudo pacman -S fzf"
      echo "     Fedora:        sudo dnf install fzf"
    fi
  else
    echo "  ✗ Unsupported OS ($OSTYPE) — install fzf manually: https://github.com/junegunn/fzf#installation"
  fi
fi

# 8. Verify deps
echo ""
echo "Checking dependencies..."
for cmd in git tmux claude gemini fzf; do
  if command -v "$cmd" >/dev/null; then
    echo "  ✓ $cmd"
  else
    echo "  ✗ $cmd NOT INSTALLED"
  fi
done

echo ""
echo "Done. Test with:"
echo "  detect-stack    # in any git repo"