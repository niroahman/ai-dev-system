# dev-system
<table>
  <tr>
    <td width="50%">
      <img width="633" height="1024" alt="image" src="https://github.com/user-attachments/assets/ec775ee6-1cdd-400a-8834-a8cf2d5d6ed9" />
    </td>
    <td width="50%">
      Multi-agent AI development pipeline — a team of specialized AI roles (Claude + Gemini) that investigate tickets, implement fixes, and review code in isolated git worktrees, orchestrated from the terminal.
    </td>
  </tr>
</table>

## How it works

Each task moves through a pipeline of specialized agents. Each runs in its
own **git worktree** — a full checkout on a dedicated branch — so agents
never interfere with each other or your working tree.

```
ticket
  └─▶ Watson   maps relevant files → .ai-team/CONTEXT.md      (Gemini Flash)
        └─▶ Nikke  investigates root cause → INVESTIGATION.md  (Claude)
              └─▶ Pat / Mat  implements fix on a branch        (Claude / Gemini)
                    └─▶ Poirot  reviews branch vs main         (Claude)
```

Watson runs **inline** (synchronously, no tmux) inside Nikke and Pat so
context is always available when the main agent starts.

**Why worktrees?** Multiple agents work in parallel without branch-switching
overhead. Each worktree gets its own `.claude/settings.json` at dispatch time,
scoping permissions to exactly what that role needs.

**Why two models?** `duel` spins Pat (Claude) and Mat (Gemini) on the same
task. Poirot compares both outputs and gives a verdict — useful for catching
blind spots either model has on a given problem.

**Context assembly** — `build-context` auto-detects the project stack
(`detect-stack`) and assembles a `.agent-context.md` from layered skill
files (`skills/_global/`, `skills/frontend/`, `skills/backend-go/`, etc.).
Agents load this at session start so stack-specific conventions are always
in scope without polluting global prompts.

## The roster

| | Name | Role | Tool |
|---|---|---|---|
| <img src="portraits/pat.png" width="60" /> | **Pat** | Worker | Claude |
| <img src="portraits/mat.png" width="60" /> | **Mat** | Worker | Gemini Flash |
| <img src="portraits/nikke.png" width="60" /> | **Nikke** | Investigator | Claude |
| <img src="portraits/poirot.png" width="60" /> | **Poirot** | Reviewer | Claude |
| | **Watson** | Context gatherer | Claude Haiku (default) / Gemini Flash |

## Setup on a new machine

```bash
git clone <this-repo-url> ~/code/dev-system
cd ~/code/dev-system
./install.sh
source ~/.zshrc
detect-stack # verify it works in any git repo
```

Add `.ai-team/` to your global gitignore so agent context never accidentally commits:

```bash
echo '.ai-team/' >> ~/.gitignore_global
git config --global core.excludesFile ~/.gitignore_global
```

## Daily workflow

### Standard bug flow

```bash
# 1. Write ticket to .ai-team/context/TICKET.md, then:
nikke WEB-7373           # new WT, Watson maps first, you edit TICKET.md → INVESTIGATION.md

# 2. Pat picks up Nikke's worktree:
pat -c                   # continues in Nikke's WT → implements fix

# 3. Poirot reviews the full branch (committed + unstaged):
poirot

# 4. Pat/Mat finish and mark themselves free automatically.
#    Worktree stays open for human review.

# 5. Commit, push PR, clean up:
wt-clean pat nikke
```

### Full recon flow

```bash
watson WEB-7373          # standalone Watson: maps codebase, editor for TICKET.md
nikke -c                 # Nikke continues in Watson's WT → INVESTIGATION.md
pat -c                   # Pat continues in Nikke's WT → fix
```

### Pat vs Mat duel

```bash
duel fix/WEB-7373        # spins Pat + Mat in parallel on same task
poirot --compare         # Poirot compares both diffs, gives verdict
wt-clean pat mat nikke
```

### Commands

| Command | Description |
|---|---|
| `watson <branch>` | Map codebase context (Claude Haiku) |
| `watson --gemini <branch>` | Map codebase with Gemini Flash |
| `watson -c` | Continue in previous Watson worktree |
| `nikke <branch>` | Investigate ticket (Watson runs inline first) |
| `nikke --gemini <branch>` | Nikke with Gemini |
| `nikke -c` | Continue in previous Nikke/Watson worktree |
| `pat <branch>` | Claude worker on new branch |
| `pat -c` | Continue in previous Nikke/Watson worktree |
| `mat <branch>` | Gemini Flash worker on new branch |
| `mat -c` | Continue in previous Nikke/Watson worktree |
| `duel <branch>` | Spin Pat and Mat on the same task |
| `poirot` | Review branch vs main (committed + unstaged) |
| `poirot --committed` | Review committed changes only |
| `poirot --compare` | Compare Pat vs Mat, give verdict |
| `roster` | Show active worktrees and status |
| `goto <pat\|mat\|nikke>` | Jump to role's tmux window/worktree |
| `wt-clean <role\|all>` | Remove worktrees after merge |

## Context folder — `.ai-team/`

All agents read from and write to `.ai-team/` in the worktree:

```
.ai-team/
  context/
    TICKET.md          — ticket written by the human
    *.md, *.png        — architecture docs, screenshots
  CONTEXT.md           — Watson's codebase map (relevant files, code paths)
  INVESTIGATION.md     — Nikke's root cause analysis and recommended fix
  REVIEW.md            — Poirot's review
  FIX-SUMMARY.md       — Pat/Mat's summary of what changed and why
  BLOCKED.md           — written when an agent hits a repeated failure
```

When a new worktree is created, `.ai-team/` is copied from main so existing
context (TICKET.md, docs, CONTEXT.md) is available immediately.

## Agent behavior

**Ordered reading** — each agent reads context in a defined order:
ticket → screenshots → architecture docs → CONTEXT.md → INVESTIGATION.md → AGENTS.md → personal skills.

**Failure handling** — if a command fails 3 times in a row, Claude agents
(`AskUserQuestion`) pause and wait for human input. Gemini agents print a
message and stop. Pat's poirot review loop caps at 2 runs.

**Free on finish** — Pat and Mat clear their tracking file when done.
`roster` shows them as idle. The worktree stays open for review; only
`wt-clean` removes it.

**Watson caps** — Watson reads at most 5 files and runs one git log command.
Designed to finish in 2-3 minutes. Use `watson --claude` to run Haiku instead
of Gemini Flash.

## Editing workflow

Files are symlinked into `~/dev-system/`, `~/.claude/`, `~/.gemini/`. Edit
them anywhere — the repo files are the live files.

```bash
nvim ~/dev-system/skills/_work/conservative.md
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

## Agent permissions

Each worktree gets `.claude/settings.json` written at dispatch time. Agents have:

- File tools: `Read`, `Write`, `Edit`, `Glob`, `Grep`
- Safe bash: `grep`, `find`, `ls`, `git ls-tree`
- Safe-tools MCP: `run_tests`, `run_install`, `run_linter`, `git_status`,
  `git_log`, `git_diff`, `git_commit`, `list_dir`, `check_tool`
- User input: `AskUserQuestion`

`Bash` (arbitrary shell) is denied. To opt a worktree into full shell access:

```json
{ "permissions": { "allow": ["Bash"] } }
```

## Design decisions

**Symlink model, never copy** — `install.sh` symlinks repo files into
`~/dev-system/` and `~/.claude/`. Editing a skill or script anywhere is a
live change with no sync step. `git diff` always shows the true state.

**Hardcoded friction** — `pat` refuses to create a 4th worktree. The cap is
intentional: agents are a tool, not a background daemon. You should always
know what's running and why.

**Roles, not prompts** — each agent has a fixed role with a fixed output
contract (`INVESTIGATION.md`, `CONTEXT.md`, `REVIEW.md`, `FIX-SUMMARY.md`).
Nikke never writes code. Pat never investigates. Clean handoffs.

**Permission by default, not by exception** — agents run with `Bash` denied.
Shell access is explicit opt-in per project, not the default.

**`.ai-team/` not `.vscode/`** — context folder is tool-agnostic and doesn't
pollute IDE config directories.

## Skill boundary

**Skills never contain work IP, codebase specifics, or team conventions.**
Those belong in each repo's `AGENTS.md`. Skills only describe behavior
preferences and stack-generic patterns.

## Portraits

Drop PNGs into `portraits/` named `pat.png`, `mat.png`, `nikke.png`,
`poirot.png`, `watson.png`. Scripts fall back to bold text if missing.

## TODO

- [ ] Watson: expose `--model <id>` flag instead of hardcoded value
- [ ] `ai-team`: BEARD coach portrait + quote set (Ted Lasso theme)
- [ ] `poirot`: post REVIEW.md summary as PR comment (optional flag)
- [ ] `roster`: show elapsed time since agent started, not worktree age
- [ ] `wt-clean`: warn if branch not merged before removing
- [ ] Stack skill files: `backend-go`, `backend-python` (currently stubs)
- [ ] Neovim+tmux variant (Phase 3)
