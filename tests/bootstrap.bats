#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_BIN="$BATS_TEST_TMPDIR/fake_bin"
	mkdir -p "$FAKE_BIN"
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME"
	BASH_BIN="$(command -v bash)"
	BOOTSTRAP="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/bootstrap.sh"
}

# ---------------------------------------------------------------------------
# BOOT-05: set -euo pipefail — static grep check
# ---------------------------------------------------------------------------

@test "BOOT-05: script contains set -euo pipefail" {
	run grep -q 'set -euo pipefail' "$BOOTSTRAP"
	assert_success
}

# ---------------------------------------------------------------------------
# BOOT-06: curl --fail --show-error — static grep check
# ---------------------------------------------------------------------------

@test "BOOT-06: script documents curl --fail --show-error usage" {
	run grep -q -- '--fail --show-error' "$BOOTSTRAP"
	assert_success
}

# ---------------------------------------------------------------------------
# BOOT-02: git installation
# ---------------------------------------------------------------------------

@test "BOOT-02: installs git when not present" {
	# apt present (for detection), apt-get installs git and records call
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	cat >"$FAKE_BIN/apt-get" <<'STUB'
#!/bin/sh
echo "$*" >> "${BATS_TEST_TMPDIR}/apt-get.log"
# Simulate git installation by creating a stub
if echo "$*" | grep -q git; then
    printf '#!/bin/sh\necho "git-called: $*"\n' > "${BATS_TEST_TMPDIR}/fake_bin/git"
    chmod +x "${BATS_TEST_TMPDIR}/fake_bin/git"
fi
exit 0
STUB
	chmod +x "$FAKE_BIN/apt-get"
	# make present
	printf '#!/bin/sh\necho "make-called: $*"\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	# copy real grep for internal use
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# git NOT in FAKE_BIN initially — bootstrap must install it
	# Pre-create DOTFILES_DIR so clone step is skipped
	mkdir -p "$FAKE_HOME/dotfiles"
	cat >"$FAKE_HOME/dotfiles/Makefile" <<'MAKEFILE'
deploy:
	echo "make deploy called"
MAKEFILE

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] Installing git..."
	run grep -q 'install' "$BATS_TEST_TMPDIR/apt-get.log"
	assert_success
}

@test "BOOT-02: skips git when already present" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/bin/sh\necho "$*" >> "${BATS_TEST_TMPDIR}/apt-get.log"\nexit 0\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	printf '#!/bin/sh\necho "git-called: $*"\n' >"$FAKE_BIN/git"
	chmod +x "$FAKE_BIN/git"
	printf '#!/bin/sh\necho "make-called: $*"\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# Pre-create DOTFILES_DIR so clone step is skipped
	mkdir -p "$FAKE_HOME/dotfiles"
	cat >"$FAKE_HOME/dotfiles/Makefile" <<'MAKEFILE'
deploy:
	echo "make deploy called"
MAKEFILE

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] git already installed, skipping."
	# apt-get.log should not contain git
	if [[ -f "$BATS_TEST_TMPDIR/apt-get.log" ]]; then
		run grep -q 'git' "$BATS_TEST_TMPDIR/apt-get.log"
		assert_failure
	fi
}

# ---------------------------------------------------------------------------
# BOOT-03: make installation
# ---------------------------------------------------------------------------

@test "BOOT-03: installs make when not present" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	cat >"$FAKE_BIN/apt-get" <<'STUB'
#!/bin/sh
echo "$*" >> "${BATS_TEST_TMPDIR}/apt-get.log"
if echo "$*" | grep -q make; then
    printf '#!/bin/sh\necho "make-called: $*"\n' > "${BATS_TEST_TMPDIR}/fake_bin/make"
    chmod +x "${BATS_TEST_TMPDIR}/fake_bin/make"
fi
exit 0
STUB
	chmod +x "$FAKE_BIN/apt-get"
	printf '#!/bin/sh\necho "git-called: $*"\n' >"$FAKE_BIN/git"
	chmod +x "$FAKE_BIN/git"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# make NOT in FAKE_BIN initially
	# Pre-create DOTFILES_DIR
	mkdir -p "$FAKE_HOME/dotfiles"
	cat >"$FAKE_HOME/dotfiles/Makefile" <<'MAKEFILE'
deploy:
	echo "make deploy called"
MAKEFILE

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] Installing make..."
	run grep -q 'install' "$BATS_TEST_TMPDIR/apt-get.log"
	assert_success
}

@test "BOOT-03: skips make when already present" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/bin/sh\necho "$*" >> "${BATS_TEST_TMPDIR}/apt-get.log"\nexit 0\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	printf '#!/bin/sh\necho "git-called: $*"\n' >"$FAKE_BIN/git"
	chmod +x "$FAKE_BIN/git"
	printf '#!/bin/sh\necho "make-called: $*"\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# Pre-create DOTFILES_DIR
	mkdir -p "$FAKE_HOME/dotfiles"
	cat >"$FAKE_HOME/dotfiles/Makefile" <<'MAKEFILE'
deploy:
	echo "make deploy called"
MAKEFILE

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] make already installed, skipping."
}

# ---------------------------------------------------------------------------
# BOOT-04: clone/pull and make deploy
# ---------------------------------------------------------------------------

@test "BOOT-04: clones repo when directory does not exist" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	# git stub: logs args, creates DOTFILES_DIR on clone
	cat >"$FAKE_BIN/git" <<'STUB'
#!/bin/sh
echo "$*" >> "${BATS_TEST_TMPDIR}/git.log"
case "$1" in
    clone)
        mkdir -p "${DOTFILES_DIR:-$HOME/.local/share/dotfiles}"
        ;;
esac
exit 0
STUB
	chmod +x "$FAKE_BIN/git"
	printf '#!/bin/sh\necho "make-called: $*"\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# DOTFILES_DIR must NOT exist before run

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] Cloning dotfiles"
	run grep -q 'clone' "$BATS_TEST_TMPDIR/git.log"
	assert_success
}

@test "BOOT-04: pulls when directory already exists" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	# git stub: logs args
	cat >"$FAKE_BIN/git" <<'STUB'
#!/bin/sh
echo "$*" >> "${BATS_TEST_TMPDIR}/git.log"
exit 0
STUB
	chmod +x "$FAKE_BIN/git"
	printf '#!/bin/sh\necho "make-called: $*"\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# Pre-create DOTFILES_DIR
	mkdir -p "$FAKE_HOME/dotfiles"

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] Dotfiles directory exists, pulling latest"
	run grep -q 'pull' "$BATS_TEST_TMPDIR/git.log"
	assert_success
}

@test "BOOT-04: runs make deploy after clone" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	# git stub: creates DOTFILES_DIR on clone
	cat >"$FAKE_BIN/git" <<'STUB'
#!/bin/sh
echo "$*" >> "${BATS_TEST_TMPDIR}/git.log"
case "$1" in
    clone)
        mkdir -p "${DOTFILES_DIR:-$HOME/.local/share/dotfiles}"
        ;;
esac
exit 0
STUB
	chmod +x "$FAKE_BIN/git"
	# make stub: logs args
	cat >"$FAKE_BIN/make" <<'STUB'
#!/bin/sh
echo "$*" >> "${BATS_TEST_TMPDIR}/make.log"
exit 0
STUB
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# DOTFILES_DIR must NOT exist before run

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_output --partial "[bootstrap] Running make deploy"
	run grep -q 'deploy' "$BATS_TEST_TMPDIR/make.log"
	assert_success
}

# ---------------------------------------------------------------------------
# BOOT-01: Happy path smoke test
# ---------------------------------------------------------------------------

@test "BOOT-01: script completes successfully on happy path" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/git"
	chmod +x "$FAKE_BIN/git"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# Pre-create DOTFILES_DIR (everything pre-installed and repo already cloned)
	mkdir -p "$FAKE_HOME/dotfiles"

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_success
}

# ---------------------------------------------------------------------------
# BOOT-05: set -euo pipefail aborts on failure
# ---------------------------------------------------------------------------

@test "BOOT-05: script aborts when command fails" {
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	# apt-get stub that always fails
	printf '#!/bin/sh\nexit 1\n' >"$FAKE_BIN/apt-get"
	chmod +x "$FAKE_BIN/apt-get"
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/make"
	chmod +x "$FAKE_BIN/make"
	cp "$(command -v grep)" "$FAKE_BIN/grep"
	# git NOT in FAKE_BIN — bootstrap will try to install it via apt-get which fails

	run env PATH="$FAKE_BIN" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
		"$BASH_BIN" "$BOOTSTRAP"
	assert_failure
}
