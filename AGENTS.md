# AGENTS.md — ai-dev-system

This is a **public repo**. Every file you create or modify may be seen by anyone.
Do not include personal info, credentials, internal URLs, company names, or work IP
in any file. If you spot any in existing files, flag it before proceeding.

## What this repo is

Personal AI development workflow toolkit — shell scripts, skill files, and global
configs for working with Claude Code and Gemini CLI. Agents (Pat, Mat, Nikke, etc.)
run in worktrees of OTHER repos; this repo is the tooling they load at session start.

## Structure

```
bin/           scripts on PATH via ~/dev-system/bin symlink
skills/        skill files loaded by build-context into .agent-context.md
  _global/     always loaded
  _personal/   loaded in personal project paths
  _work/       loaded in work project paths
  frontend/    loaded when package.json has react/next/vue/svelte
  backend-go/  loaded when go.mod present
  backend-python/ loaded when pyproject.toml/requirements.txt present
  monorepo/    loaded when apps/ packages/ services/ or workspace config present
claude/        CLAUDE.md — symlinked to ~/.claude/CLAUDE.md by install.sh
gemini/        GEMINI.md — symlinked to ~/.gemini/GEMINI.md by install.sh
portraits/     PNG portraits for each role (pat, mat, nikke, poirot, watson)
install.sh     idempotent setup script — symlinks everything, sets PATH, gitignore
```

## The roster

| Script | Role | Tool | Description |
|---|---|---|---|
| `watson` | Context gatherer | Gemini Flash (default) / Claude Haiku | Maps relevant files/code paths, writes CONTEXT.md. Runs inline inside nikke/pat/mat. |
| `nikke` | Investigator | Claude | Investigates tickets, writes INVESTIGATION.md. Calls Watson inline first. |
| `pat` | Worker | Claude | Implements fixes/features. Clears its tracking on finish — free for next task. |
| `mat` | Worker | Gemini Flash | Same as Pat, Gemini variant. Symlink to pat. |
| `ai-team` | — | — | fzf menu: choose your fighter. Retro arcade flow selector. |
| `duel` | — | Both | Spins Pat and Mat on the same task for comparison. |
| `poirot` | Reviewer | Claude | Reviews branch vs main (committed + unstaged), writes REVIEW.md. |
| `goto` | — | — | Jumps to a role's tmux session. |
| `roster` | — | — | Shows active worktrees and status. Idle if tracking cleared. |
| `wt-clean` | — | — | Removes worktrees after merge. |
| `detect-stack` | — | — | Detects stacks in a repo, prints layer names. |
| `build-context` | — | — | Assembles .agent-context.md from detected skill layers. |

`_lib.sh` is sourced by all scripts — contains shared helpers:
`resolve_role`, `resolve_named_role`, `setup_worktree`, `find_continue_wt`,
`run_watson_inline`, `write_claude_settings`, `launch_tmux`, `track_worktree`.

## Context folder

All agents share `.ai-team/` in the worktree root:

```
.ai-team/
  context/
    TICKET.md          — ticket written by the human
    *.md, *.png        — architecture docs, diagrams, screenshots
  CONTEXT.md           — Watson's codebase map
  INVESTIGATION.md     — Nikke's root cause analysis
  REVIEW.md            — Poirot's review output
  FIX-SUMMARY.md       — Pat/Mat's summary of changes
  BLOCKED.md           — written when an agent hits a loop and stops
```

When a new worktree is created, the entire `.ai-team/` folder is copied from
main so all existing context is available immediately.

Add `.ai-team/` to your global gitignore:

```sh
echo '.ai-team/' >> ~/.gitignore_global
git config --global core.excludesFile ~/.gitignore_global
```

## Workflow

### Quick reference

```
# Full flow: Watson → Nikke → Pat
watson WEB-7373              # new WT, editor TICKET.md → CONTEXT.md
nikke -c                     # continue into same WT → INVESTIGATION.md
pat -c                       # continue into same WT → FIX

# Skip Watson, Nikke first
nikke login-bug              # new WT, Watson runs inline, editor → INVESTIGATION.md
pat -c                       # continue → FIX

# Solo fix
pat fix/branch               # new WT, Watson runs inline → FIX

# Compare
duel fix/branch              # two new WTs (Pat + Mat)
poirot --compare             # Poirot compares both, gives verdict

# Cleanup
wt-clean pat nikke
```

### Commands

| Command | Worktree | Description |
|---------|----------|-------------|
| `watson <branch>` | new | Map codebase. Default Gemini Flash. |
| `watson --claude <branch>` | new | Map codebase with Claude Haiku. |
| `watson -c` | previous | Continue in last Watson worktree. |
| `nikke <branch>` | new | Investigate. Watson runs inline first. |
| `nikke -c` | previous | Continue in last Nikke/Watson worktree. |
| `nikke --gemini <branch>` | new | Nikke with Gemini instead of Claude. |
| `pat <branch>` / `mat <branch>` | new | Worker on new branch. |
| `pat -c` / `mat -c` | previous | Continue in last Nikke/Watson worktree. |
| `pat -c -w /path` | explicit | Continue in specific path. |
| `duel <branch>` | two new | Spin Pat and Mat on the same task. |
| `poirot` | current | Review branch vs main (committed + unstaged). |
| `poirot --committed` | current | Review committed changes only. |
| `poirot --compare` | current | Compare Pat vs Mat outputs. |

### How it works

1. **New worktree**: `<script> <branch>` creates a git worktree, copies
   `.ai-team/` from main, opens `$EDITOR` for TICKET.md. On save+exit,
   the agent launches in its own tmux session.

2. **Continue**: `<script> -c` finds the most recent worktree (Nikke's, then
   Watson's), frees the previous owner (clears tracking, kills session),
   and launches the next agent in the same worktree.

3. **Watson inline**: When nikke or pat create a new worktree, Watson runs
   synchronously first to build CONTEXT.md before the main agent starts.

4. **Tmux**: Inside tmux, sessions start detached (`goto <role>` to switch).
   Outside tmux, they attach directly.

5. **Free on finish**: Pat/Mat clear their tracking file (`~/.pat_last_worktree`,
   `~/.mat_last_worktree`) when done. `roster` shows them as idle. The worktree
   stays open for human review — only `wt-clean` removes it.

6. **Failure handling**: If a command fails 3 times in a row, Claude agents
   (Pat, Nikke) use `AskUserQuestion` to surface the block and wait for input.
   Gemini agents (Mat, Watson) print a message and stop.

## Agent permissions

`write_claude_settings` in `_lib.sh` writes `.claude/settings.json` to each
worktree at dispatch time. Agents get:

- File tools: `Read`, `Write`, `Edit`, `Glob`, `Grep`
- Planning: `EnterPlanMode`, `ExitPlanMode`
- Tasks: `TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`, `TaskOutput`, `TaskStop`
- User input: `AskUserQuestion`
- Safe bash: `Bash(grep:*)`, `Bash(find:*)`, `Bash(ls:*)`, `Bash(git ls-tree:*)`
- Safe-tools MCP: `run_tests`, `run_install`, `run_linter`, `git_status`,
  `git_log`, `git_diff`, `git_commit`, `list_dir`, `check_tool`

`Bash` (general shell) is denied. Agents cannot run arbitrary commands.

## Conventions

**Symlink model** — `install.sh` symlinks `bin/`, `skills/`, `portraits/`, `claude/CLAUDE.md`,
and `gemini/GEMINI.md` into `~/dev-system/` and `~/.claude/`/`~/.gemini/`. Never copy files.
Edit in the repo; changes are live immediately via symlinks.

**Paths** — always use `$HOME`, never hardcode `/Users/...`. Scripts must work on any machine.

**Scripts** — source `_lib.sh` near the top. Use `resolve_named_role <Name>` to get
`$ROLE_NAME` and `$ROLE_PORTRAIT_MD`. Add `chmod +x bin/<script>` after creating new scripts.

**Skills boundary** — skill files describe behavior preferences and stack-generic patterns only.
No work IP, codebase specifics, or team conventions. Those belong in each project's `AGENTS.md`.

**No test suite** — verify changes with `./install.sh` (idempotent) and `detect-stack` in a
real repo. Check that symlinks resolve correctly after install.

## When working in this repo

- Smallest viable change — this tooling is used daily, breakage has immediate impact
- After editing any script: confirm it still sources `_lib.sh` correctly and `$HOME` paths are intact
- After editing skill files: check that `build-context` would still assemble them correctly
- Do not add role-specific logic to `_lib.sh` — keep it to shared helpers only
