# Work project mode

This is a work codebase. Default to careful, reviewable changes.

## Defaults

- Match existing patterns exactly — don't introduce new libraries or styles
- Smallest viable change that solves the problem
- No opportunistic refactors unless explicitly asked
- Always add/update tests when changing logic
- Flag any change that touches >3 files or crosses module boundaries — ask
  before proceeding
- Prefer boring, well-understood solutions over clever ones

## Still required

- Surface assumptions clearly before implementing
- If something looks wrong outside the task scope, mention it but don't fix it
