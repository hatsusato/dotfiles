# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Tests

Initialize BATS submodules (required once after clone):
```bash
git submodule update --init --recursive
```

Run all tests:
```bash
tests/bats/bin/bats tests/bootstrap.bats tests/env-detect.bats
```

Run a single test file:
```bash
tests/bats/bin/bats tests/env-detect.bats
```

Run a single test by name/ID:
```bash
tests/bats/bin/bats tests/bootstrap.bats -f "BOOT-01"
```

### Linting

Pre-commit hooks run `shellcheck`, `shfmt`, and line-ending checks. Set them up with:
```bash
pip install pre-commit && pre-commit install
```

Run hooks manually:
```bash
pre-commit run --all-files
```

## Important

### Do NOT commit .planning/ directory

The `.planning/` directory is explicitly listed in `.gitignore` and must NEVER be committed to git.

**Rule:** When creating commits (via `gsd-tools commit` or `git commit`), do NOT include any files from `.planning/`.

This applies to ALL agents and all workflows:
- STATE.md
- ROADMAP.md
- SUMMARY.md
- PLAN.md
- CONTEXT.md
- VERIFICATION.md
- Any other file in `.planning/`

**Implementation guidance:** When the gsd-executor agent creates commits, it should ONLY commit files from the working directory (`src/`, `tests/`, `lib/`, `dotfiles/`, config files, etc.). If the agent's workflow uses STATE.md or other .planning files for state management, that's fine — just don't add them to commits.

**Enforcement:** Use `git check-ignore` to verify before committing:
```bash
git check-ignore .planning/STATE.md  # Returns 0 (ignored) ✓
```

### Code Comments Must Be in English

All source code comments (inline comments, function docstrings, block comments) must be written in **English**.

**Why:** This keeps the codebase accessible and maintainable across different environments and team contexts.

**Example:**
```bash
# ✓ Good: English comment
# Load config files in alphabetical order
for file in "${config_dir}"/*.sh; do
  source "$file"
done

# ✗ Bad: Japanese comment
# 設定ファイルを英数字順にロード
for file in "${config_dir}"/*.sh; do
  source "$file"
done
```

### Avoid shellcheck Disable Directives

Do **NOT** use `shellcheck disable=SC####` directives to suppress warnings. Instead:

1. **Fix the code** if shellcheck is correct (most cases)
2. **Restructure** so shellcheck can verify correctness without flags (preferred over any annotation)
3. **Use `shellcheck source=`** to help shellcheck understand included files
4. **Justify inline** with a clear comment explaining why the pattern is necessary (rare, last resort)

If you find yourself wanting to disable a check, that's a sign the code pattern may need rethinking.

#### shellcheck and --external-sources

`--external-sources` (or `-x`) allows shellcheck to follow dynamic `source` paths. It is used in
`make lint-strict` and in pre-commit as the CI gate.

`--external-sources` is **required** for SC1091 (cannot follow dynamic `source` paths like
`source "${SCRIPT_DIR}/..."`) when the source path uses a variable. In that case:

- Keep the `# shellcheck source=<path>` hint with the correct path **relative to the project root** (not relative to the file being analyzed)
- Do NOT add `# shellcheck disable=SC1091` — let `--external-sources` handle it

```bash
# ✗ Avoid:
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/safe-delete.sh"

# ✓ Correct: fix source= path relative to project root, rely on --external-sources
# shellcheck source=lib/safe-delete.sh
source "${SCRIPT_DIR}/lib/safe-delete.sh"
```

#### Common fixes by warning

```bash
# SC2034 — variable appears unused across files
# ✗ Avoid:
# shellcheck disable=SC2034
LOG_PREFIX="deploy"
# ✓ Fix: expose via setter function defined in the library
set_log_prefix "deploy"   # set_log_prefix() defined in logging.sh

# SC2250 — prefer braces around variable references
# ✗ Avoid: $var
# ✓ Fix: ${var}

# SC2310 — function in if/&&/|| condition disables set -e
# ✗ Avoid:
if is_wsl; then ...
# ✓ Fix: invoke separately, capture exit code
is_wsl
local _is_wsl=$?
if [[ _is_wsl -eq 0 ]]; then ...

# SC2312 — command substitution masks return value
# ✗ Avoid:
eval "$(bash script.sh)"
# ✓ Fix: separate into two steps
_out=$(bash script.sh)
eval "${_out}"
unset _out
```

#### shellcheck and --external-sources

**Basic policy: fix code structure so shellcheck passes _without_ `--external-sources`.**

Before reaching for `--external-sources`, try these structural fixes first:

| Warning | Structural fix (no --external-sources needed) |
|---------|-----------------------------------------------|
| SC2034 (variable appears unused) | Move assignment into the library; expose via a setter function (e.g. `set_log_prefix`) |
| SC2250 (prefer braces) | Use `${var}` everywhere |
| SC2310 (set -e disabled in condition) | Invoke function separately; capture `$?` on the next line |
| SC2312 (command substitution masks return value) | Assign to variable first, then eval/use |

`--external-sources` is **acceptable** only for SC1091 (cannot follow dynamic `source` paths like
`source "${SCRIPT_DIR}/..."`) when there is no static alternative. In that case:

- Keep the `# shellcheck source=<path>` hint with the correct path **relative to the project root** (not relative to the file being analyzed)
- Do NOT add `# shellcheck disable=SC1091` — let `--external-sources` handle it

## Architecture

This repository is a personal dotfiles deployment system for Linux, WSL, and Git Bash on Windows, built with a strict TDD workflow.

### TDD Methodology

Commits follow Red → Green cycles: tests are written first (failing), then implementation is added to make them pass. When adding features, write the BATS test first.

Commit message convention: `type(phase-step): description (TEST-ID)`

### Key Components

**`bootstrap.sh`** — The one-liner entry point for fresh machine setup. It installs git and make if missing, clones/pulls the repo, then delegates to `make deploy` (not yet implemented). Invoked via `curl -L ... | bash` or directly.

**`lib/env-detect.sh`** — Environment detection utility. Detects `ENV_TYPE` (wsl/gitbash/linux), `PACKAGE_MANAGER` (apt/dnf/pacman/scoop), and `HAS_SUDO` (true/false). Outputs bash `declare` statements suitable for sourcing. WSL detection checks `uname -r` and `/proc/version` for "microsoft" and takes priority over Git Bash detection.

**`dotfiles/`** — Seed config files organized by OS: `common/` (git config), `linux/`, `wsl/`, `gitbash/`. Deployment logic (symlinking/copying to `$HOME`) is not yet implemented — the `Makefile` with `make deploy` target is still pending.

**`tests/`** — BATS test suite. `bootstrap.bats` (8 tests, IDs BOOT-01–BOOT-08) and `env-detect.bats` (15 tests, IDs OSDT-01–OSDT-05). Tests use isolated `BATS_TEST_TMPDIR` with fake binaries to mock system tools without modifying the real system.

### What Is Not Yet Implemented

- `Makefile` with `deploy` target (referenced by `bootstrap.sh`)
- `.github/workflows/lint-bootstrap.yml` (expected by BOOT-08 test)
- Dotfile deployment/symlinking logic
