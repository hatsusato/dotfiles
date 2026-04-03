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
