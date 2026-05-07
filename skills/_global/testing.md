# Testing

Before writing FIX-SUMMARY.md, discover and run all available test/lint
commands. Steps:

1. Check AGENTS.md for test commands — use those if documented
2. Otherwise inspect package.json `scripts` for: test, lint, typecheck,
   e2e, playwright, vitest, jest — run each that exists
3. For Go repos: `go test ./...`
4. For Python repos: check for pytest, ruff, mypy

Include results in FIX-SUMMARY.md under ## Tests:

- Each command run
- Pass / fail / skip count
- Any new failures introduced (file:line)
- Any commands that were skipped and why

If a command fails, fix the failure before writing FIX-SUMMARY.md — do not
leave broken tests. Exception: if a test was already failing on main before
your changes, note it as pre-existing and do not fix it.

If no test suite exists, note that explicitly.
