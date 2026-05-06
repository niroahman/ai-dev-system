# dev-system

Personal AI development workflow — skills, scripts, and configs for working
with Claude Code and Gemini CLI.

The roster: **Pat** (Claude worker), **Mat** (Gemini worker),
**Nikke** (investigator), **Poirot** (reviewer).

## Setup on a new machine

```bash
git clone <this-repo-url> ~/code/dev-system
cd ~/code/dev-system
./install.sh
source ~/.zshrc
detect-stack # verify it works in any git repo
```

## Editing workflow

Files are symlinked into `~/dev-system/`, `~/.claude/`, `~/.gemini/`. Edit
them anywhere — the repo files are the live files.

```bash
nvim ~/dev-system/skills/_work/conservative.md # via the symlink
cd ~/code/dev-system
git diff
git add -A
git commit -m "tweak conservative skill"
git push
```

## Pulling updates on another machine

```bash
cd ~/code/dev-system
git pull
./install.sh # idempotent
```

## Portraits

Drop PNGs into `portraits/` named `pat.png`, `mat.png`, `nikke.png`,
`poirot.png`. Empty placeholders are fine — scripts fall back to bold text
until real images are present.

See docs/DEV-SYSTEM-SETUP.md for the full workflow design.
