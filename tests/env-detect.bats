#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_BIN="$BATS_TEST_TMPDIR/fake_bin"
	mkdir -p "$FAKE_BIN"
	MOCK_PROC="$BATS_TEST_TMPDIR/proc"
	mkdir -p "$MOCK_PROC"
	BASH_BIN="$(command -v bash)"
}

# ---------------------------------------------------------------------------
# OSDT-01 + OSDT-02: ENV_TYPE detection and declare output format
# ---------------------------------------------------------------------------

@test "OSDT-01: Linux detected when no WSL signals and no MSYSTEM" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="linux"'
}

@test "OSDT-01: WSL detected when uname -r contains microsoft" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.90.1-microsoft-standard-WSL2" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.90.1-microsoft-standard-WSL2 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="wsl"'
}

@test "OSDT-01: Git Bash detected when MSYSTEM is set and not WSL" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "3.4.9-be826601.x86_64" ;;
-s) echo "MINGW64_NT-10.0-19045" ;;
*) echo "MINGW64_NT-10.0-19045" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/scoop"
	chmod +x "$FAKE_BIN/scoop"

	run env PATH="$FAKE_BIN" MSYSTEM=MINGW64 PROC_VERSION_FILE="$MOCK_PROC/version" \
		"$BASH_BIN" lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="gitbash"'
}

@test "OSDT-01: Unknown OS exits with error" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "24.1.0" ;;
-s) echo "Darwin" ;;
*) echo "Darwin" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Darwin" >"$MOCK_PROC/version"

	run env PATH="$FAKE_BIN" PROC_VERSION_FILE="$MOCK_PROC/version" \
		"$BASH_BIN" lib/env-detect.sh

	assert_failure
}

@test "OSDT-02: Output uses declare format for all variables" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/sudo"
	chmod +x "$FAKE_BIN/sudo"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="'
	assert_output --partial 'declare -- PACKAGE_MANAGER="'
	assert_output --partial 'declare -- HAS_SUDO="'
}

# ---------------------------------------------------------------------------
# OSDT-03: WSL multi-signal detection
# ---------------------------------------------------------------------------

@test "OSDT-03: WSL detected via uname -r only" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.90.1-microsoft-standard-WSL2" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	# /proc/version does NOT contain microsoft
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="wsl"'
}

@test "OSDT-03: WSL detected via /proc/version only" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	# /proc/version DOES contain microsoft
	echo "Linux version 5.15.0 (Microsoft@Microsoft.com)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="wsl"'
}

@test "OSDT-03: WSL takes priority over MSYSTEM" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.90.1-microsoft-standard-WSL2" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.90.1-microsoft-standard-WSL2 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"

	# Both WSL signals AND MSYSTEM set — WSL must win
	PATH="$FAKE_BIN:$PATH" MSYSTEM=MINGW64 PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- ENV_TYPE="wsl"'
}

# ---------------------------------------------------------------------------
# OSDT-04: Package manager detection
# ---------------------------------------------------------------------------

@test "OSDT-04: apt detected on Linux" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- PACKAGE_MANAGER="apt"'
}

@test "OSDT-04: dnf detected on Linux when no apt" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	# No apt — only dnf
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/dnf"
	chmod +x "$FAKE_BIN/dnf"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- PACKAGE_MANAGER="dnf"'
}

@test "OSDT-04: pacman detected on Linux when no apt or dnf" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	# No apt, no dnf — only pacman
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/pacman"
	chmod +x "$FAKE_BIN/pacman"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- PACKAGE_MANAGER="pacman"'
}

@test "OSDT-04: scoop detected on Git Bash" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "3.4.9-be826601.x86_64" ;;
-s) echo "MINGW64_NT-10.0-19045" ;;
*) echo "MINGW64_NT-10.0-19045" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/scoop"
	chmod +x "$FAKE_BIN/scoop"

	run env PATH="$FAKE_BIN" MSYSTEM=MINGW64 PROC_VERSION_FILE="$MOCK_PROC/version" \
		"$BASH_BIN" lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- PACKAGE_MANAGER="scoop"'
}

@test "OSDT-04: No package manager exits with error" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	# No package managers — PATH restricted so real apt/dnf/pacman are hidden
	run env PATH="$FAKE_BIN" PROC_VERSION_FILE="$MOCK_PROC/version" \
		"$BASH_BIN" lib/env-detect.sh

	assert_failure
}

# ---------------------------------------------------------------------------
# OSDT-05: HAS_SUDO detection
# ---------------------------------------------------------------------------

@test "OSDT-05: HAS_SUDO=true when sudo is available" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/sudo"
	chmod +x "$FAKE_BIN/sudo"

	PATH="$FAKE_BIN:$PATH" PROC_VERSION_FILE="$MOCK_PROC/version" \
		run bash lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- HAS_SUDO="true"'
}

@test "OSDT-05: HAS_SUDO=false when sudo is not available" {
	cat >"$FAKE_BIN/uname" <<'UNAME'
#!/usr/bin/env bash
case "$1" in
-r) echo "5.15.0-generic" ;;
-s) echo "Linux" ;;
*) echo "Linux" ;;
esac
UNAME
	chmod +x "$FAKE_BIN/uname"
	echo "Linux version 5.15.0 (gcc)" >"$MOCK_PROC/version"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$FAKE_BIN/apt"
	chmod +x "$FAKE_BIN/apt"
	# No sudo in FAKE_BIN — PATH restricted so real sudo is hidden
	run env PATH="$FAKE_BIN" PROC_VERSION_FILE="$MOCK_PROC/version" \
		"$BASH_BIN" lib/env-detect.sh

	assert_success
	assert_output --partial 'declare -- HAS_SUDO="false"'
}
