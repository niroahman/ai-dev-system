#!/bin/bash
# install.sh — run after cloning the repo on a new machine
# Idempotent: safe to re-run after pulling updates
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing dev-system from $REPO_DIR"

# 1. Symlink the repo's bin/ skills/ prompts/ portraits/ into ~/dev-system/
mkdir -p "$HOME/dev-system"
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
for entry in ".vscode/ai/" ".agent-context.md" ".agent-task.md" ".investigate-prompt.md" ".ticket/" "INVESTIGATION.md" "REVIEW.md"; do
  grep -qxF "$entry" "$GIG" || echo "$entry" >> "$GIG"
done
git config --global core.excludesfile "$GIG"

# 5. Make scripts executable (in case clone didn't preserve)
chmod +x "$REPO_DIR/bin/"* 2>/dev/null || true

# 6. Verify deps
echo ""
echo "Checking dependencies..."
for cmd in git tmux claude gemini; do
  if command -v "$cmd" >/dev/null; then
    echo "  ✓ $cmd"
  else
    echo "  ✗ $cmd NOT INSTALLED"
  fi
done

echo ""
echo "Done. Test with:"
echo "  detect-stack    # in any git repo"
