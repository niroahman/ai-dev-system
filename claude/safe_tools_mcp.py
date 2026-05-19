# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=1.0"]
# ///
"""
Safe Tools MCP Server — global L5 companion for Claude Code.

Bash is denied in ~/.claude/settings.json. This server gives agents
narrow, purpose-built execution tools instead:

  git       : git_status, git_log, git_diff, git_commit
  tests     : run_tests  (auto-detects pytest / npm / cargo / go / make)
  deps      : run_install (auto-detects uv / npm / cargo / go)
  quality   : run_linter (auto-detects ruff / biome / eslint)
  fs        : list_dir   (names only, no contents)
  meta      : check_tool (which <name>)

Launched via settings.json mcpServers stanza (stdio transport).
"""

from pathlib import Path
import shutil
import subprocess

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("safe-tools")


# ── helpers ──────────────────────────────────────────────────────────────────

def _run(cmd: list[str], timeout: int = 120) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=Path.cwd())
    return (result.stdout + result.stderr).strip()

def _node_pm(cwd: Path) -> str:
    if (cwd / "pnpm-lock.yaml").exists():
        return "pnpm"
    if (cwd / "yarn.lock").exists():
        return "yarn"
    return "npm"


# ── git ──────────────────────────────────────────────────────────────────────

@mcp.tool()
def git_status() -> str:
    """Short git status (porcelain + branch) for the current working directory."""
    try:
        return _run(["git", "status", "--porcelain", "-b"]) or "(clean)"
    except FileNotFoundError:
        return "git not installed on PATH"


@mcp.tool()
def git_log(n: int = 10) -> str:
    """Show recent git commits (--oneline). n: number of commits, max 50."""
    try:
        return _run(["git", "log", f"-{min(n, 50)}", "--oneline"]) or "(no commits)"
    except FileNotFoundError:
        return "git not installed on PATH"


@mcp.tool()
def git_diff(staged: bool = False) -> str:
    """Show current changes. staged=True for --staged. Returns trailing 4KB."""
    args = ["git", "diff"] + (["--staged"] if staged else [])
    try:
        output = _run(args)
        return output[-4000:] if output else "(no changes)"
    except FileNotFoundError:
        return "git not installed on PATH"


@mcp.tool()
def git_commit(message: str, stage_all: bool = True) -> str:
    """Commit changes. stage_all=True runs git add -A first (includes new files)."""
    try:
        if stage_all:
            _run(["git", "add", "-A"])
        return _run(["git", "commit", "-m", message])
    except FileNotFoundError:
        return "git not installed on PATH"


# ── tests ────────────────────────────────────────────────────────────────────

@mcp.tool()
def run_tests() -> str:
    """Auto-detect and run the project test suite. Returns trailing 2KB of output."""
    cwd = Path.cwd()
    try:
        if (cwd / "pyproject.toml").exists() or (cwd / "setup.py").exists() or (cwd / "requirements.txt").exists():
            cmd = ["uv", "run", "pytest", "-q"] if shutil.which("uv") else ["pytest", "-q"]
        elif (cwd / "package.json").exists():
            cmd = [_node_pm(cwd), "test"]
        elif (cwd / "Cargo.toml").exists():
            cmd = ["cargo", "test"]
        elif (cwd / "go.mod").exists():
            cmd = ["go", "test", "./..."]
        elif (cwd / "Makefile").exists():
            cmd = ["make", "test"]
        else:
            return "no test runner detected (checked: pyproject.toml, package.json, Cargo.toml, go.mod, Makefile)"
        return _run(cmd)[-2000:] or "(no output)"
    except subprocess.TimeoutExpired:
        return "test run timed out (120s)"


# ── deps ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def run_install() -> str:
    """Auto-detect and install project dependencies. Returns trailing 2KB of output."""
    cwd = Path.cwd()
    try:
        if (cwd / "pyproject.toml").exists() and shutil.which("uv"):
            cmd = ["uv", "sync"]
        elif (cwd / "requirements.txt").exists() and shutil.which("uv"):
            cmd = ["uv", "pip", "install", "-r", "requirements.txt"]
        elif (cwd / "package.json").exists():
            cmd = [_node_pm(cwd), "install"]
        elif (cwd / "Cargo.toml").exists():
            cmd = ["cargo", "fetch"]
        elif (cwd / "go.mod").exists():
            cmd = ["go", "mod", "download"]
        else:
            return "no package manager detected (checked: pyproject.toml, requirements.txt, package.json, Cargo.toml, go.mod)"
        return _run(cmd)[-2000:] or "(done)"
    except subprocess.TimeoutExpired:
        return "install timed out (120s)"


# ── quality ──────────────────────────────────────────────────────────────────

@mcp.tool()
def run_linter() -> str:
    """Auto-detect and run linter: ruff (Python), biome then eslint (JS/TS). Returns trailing 2KB."""
    cwd = Path.cwd()

    if list(cwd.rglob("*.py")) and shutil.which("ruff"):
        output = _run(["ruff", "check", "."]) or "(no issues)"
        return f"[ruff]\n{output[-2000:]}"

    if list(cwd.rglob("*.ts")) or list(cwd.rglob("*.js")):
        if shutil.which("biome"):
            output = _run(["biome", "check", "."]) or "(no issues)"
            return f"[biome]\n{output[-2000:]}"
        if shutil.which("eslint"):
            output = _run(["eslint", "."]) or "(no issues)"
            return f"[eslint]\n{output[-2000:]}"

    return "no linter found (checked: ruff, biome, eslint)"


# ── fs ───────────────────────────────────────────────────────────────────────

@mcp.tool()
def list_dir(path: str = ".") -> str:
    """List filenames in a directory. Returns NAMES only — does NOT return file contents."""
    target = Path(path).expanduser().resolve()
    if not target.exists():
        return f"{path} does not exist"
    if not target.is_dir():
        return f"{path} is not a directory"
    return "\n".join(sorted(p.name for p in target.iterdir())) or "(empty)"


# ── meta ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def check_tool(name: str) -> str:
    """Check if a CLI tool is available on PATH. Returns its path or 'not found'."""
    path = shutil.which(name)
    return path if path else f"{name}: not found"


if __name__ == "__main__":
    mcp.run()
