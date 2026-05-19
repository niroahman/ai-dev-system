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
| `nikke` | Investigator | Claude | Investigates tickets, writes INVESTIGATION.md. Calls Watson first. |
| `watson` | Context gatherer | Gemini Flash | Maps relevant files/code paths, writes CONTEXT.md. |
| `pat` | Worker | Claude | Implements fixes/features on a branch. |
| `mat` | Worker | Gemini Flash | Same as Pat, Gemini variant. |
| `duel` | — | Both | Spins Pat and Mat on the same task for comparison. |
| `poirot` | Reviewer | Claude | Reviews a worktree, writes REVIEW.md to brief the human. |
| `goto` | — | — | Jumps to a role's tmux window/worktree. |
| `roster` | — | — | Shows active worktrees and status. |
| `wt-clean` | — | — | Removes worktrees after merge. |
| `detect-stack` | — | — | Detects stacks in a repo, prints layer names. |
| `build-context` | — | — | Assembles .agent-context.md from detected skill layers. |

`_lib.sh` is sourced by all scripts — contains `resolve_role` and `resolve_named_role`.

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
