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
  └─▶ Watson   maps relevant files → CONTEXT.md       (Gemini Flash, fast)
        └─▶ Nikke  investigates root cause → INVESTIGATION.md  (Claude)
              └─▶ Pat / Mat  implements fix on a branch        (Claude / Gemini)
                    └─▶ Poirot  reviews, writes REVIEW.md      (Claude)
```

**Why worktrees?** Multiple agents work in parallel without branch-switching
overhead. Each worktree gets its own `.claude/settings.json` written at
dispatch time, scoping permissions to exactly what that role needs.

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
| <img src="portraits/mat.png" width="60" /> | **Mat** | Worker | Gemini |
| <img src="portraits/nikke.png" width="60" /> | **Nikke** | Investigator | Claude |
| <img src="portraits/poirot.png" width="60" /> | **Poirot** | Reviewer | Claude |
| | **Watson** | Context gatherer | Gemini Flash |

## Setup on a new machine

```bash
git clone <this-repo-url> ~/code/dev-system
cd ~/code/dev-system
./install.sh
source ~/.zshrc
detect-stack # verify it works in any git repo
```

## Daily workflow

### Standard bug flow

```bash
# 1. Copy ticket to clipboard, then:
nikke -t PROJ-123-bug-name

# 2. Read .vscode/ai/INVESTIGATION.md in Nikke's worktree
# 3. Dispatch Pat with Nikke's findings:
pat -n bug/PROJ-123-bug-name

# 4. When Pat finishes, jump to its worktree and review:
goto pat
poirot

# 5. Commit, push PR, clean up:
wt-clean pat nikke
```

### Pat vs Mat duel

```bash
duel -n fix/PROJ-123-branch      # spins both with Nikke's investigation
goto pat
poirot --compare                  # Poirot compares both, gives verdict
wt-clean pat mat nikke
```

### Commands

| Command | Description |
|---|---|
| `watson -t <title>` | Map codebase context for a ticket (Gemini Flash) |
| `nikke -t <title>` | Investigate ticket from clipboard (Watson runs first) |
| `nikke --no-watson -t <title>` | Investigate without Watson pre-mapping |
| `pat <branch> "task"` | Claude worker on a new branch |
| `pat -n <branch>` | Claude worker, pulls Nikke's investigation |
| `mat <branch> "task"` | Gemini Flash worker on a new branch |
| `mat -n <branch>` | Gemini Flash worker, pulls Nikke's investigation |
| `duel [-n] <branch>` | Spin Pat and Mat on the same task |
| `poirot` | Review current worktree |
| `poirot --compare` | Compare Pat vs Mat, give verdict |
| `roster` | Show active worktrees and status |
| `goto <pat\|mat\|nikke>` | Jump to role's tmux window/worktree |
| `wt-clean <role\|all>` | Remove worktrees after merge |

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

## Agent permissions

`.claude/settings.json` at the repo root restricts agents to a safe subset
of tools — no shell access. This applies only to this repo and does not
touch your global `~/.claude/` settings.

Agents get narrow replacements through the **safe-tools MCP server**
(configured globally via your dotfiles — see `env/dot-claude/safe_tools_mcp.py`):

| Tool | What it does |
|---|---|
| `git_status` | `git status --porcelain -b` |
| `git_log` | `git log --oneline` (max 50) |
| `git_diff` | `git diff` or `git diff --staged` |
| `git_commit` | `git add -A && git commit -m` |
| `run_tests` | auto-detects pytest / npm / cargo / go / make |
| `run_install` | auto-detects uv / npm / cargo / go |
| `run_linter` | auto-detects ruff / biome / eslint |
| `list_dir` | filenames only, no file contents |
| `check_tool` | `which <name>` |

To opt a worktree back in to `Bash`, add `.claude/settings.json` there:

```json
{ "permissions": { "allow": ["Bash"] } }
```

### Going global

You can promote these same restrictions to `~/.claude/settings.json` to
cover every project on your machine. Benefits:

- **Default-safe** — new repos and one-off sessions are restricted without
  any per-project setup
- **Consistent agent behavior** — Pat, Nikke, and any ad-hoc Claude session
  all operate under the same rules
- **Explicit opt-in for shell access** — projects that need `Bash` declare it
  in their own `.claude/settings.json`, making the permission visible in the repo

Copy the permission block from this file's `.claude/settings.json` into your
`~/.claude/settings.json` to get started. Add the `mcpServers` stanza from
`claude/safe_tools_mcp.py` if you want the safe-tools available everywhere.

## Design decisions

**Symlink model, never copy** — `install.sh` symlinks repo files into
`~/dev-system/` and `~/.claude/`. Editing a skill or script anywhere is a
live change with no sync step. `git diff` always shows the true state.

**Hardcoded friction** — `pat` refuses to create a 4th worktree. The cap is
intentional: agents are a tool, not a background daemon. You should always
know what's running and why.

**Roles, not prompts** — each agent has a fixed role with a fixed output
contract (`INVESTIGATION.md`, `CONTEXT.md`, `REVIEW.md`). Separation of
concerns means Nikke never writes code and Pat never investigates. Cleaner
handoffs, easier to spot when an agent goes off-script.

**Permission by default, not by exception** — agents run with `Bash` denied
at the repo level. Shell access is an explicit opt-in per project, not the
default. The safe-tools MCP server provides git and test operations without
granting arbitrary execution.

## Skill boundary

**Skills never contain work IP, codebase specifics, or team conventions.**
Those belong in each repo's `AGENTS.md`. Skills only describe behavior
preferences and stack-generic patterns.

When tempted to add work-specific knowledge to a skill, push it to the
team's `AGENTS.md` instead — it belongs where teammates can read it.

## Portraits

Drop PNGs into `portraits/` named `pat.png`, `mat.png`, `nikke.png`,
`poirot.png`, `watson.png`. Empty placeholders are fine — scripts fall back
to bold text until real images are present.
