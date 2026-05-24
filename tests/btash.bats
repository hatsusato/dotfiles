#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

teardown() {
	if [[ -n "${LIVE_SESSION_PID:-}" ]]; then
		kill "$LIVE_SESSION_PID" 2>/dev/null || true
		wait "$LIVE_SESSION_PID" 2>/dev/null || true
	fi
}

setup() {
	PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
	BASH_BIN="$(command -v bash)"
	BTASH="$PROJECT_ROOT/dotfiles/common/.local/bin/btash"
	FAKE_BIN="$BATS_TEST_TMPDIR/fake_bin"
	RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
	LIVE_SESSION_PID=""

	mkdir -p "$FAKE_BIN" "$RUNTIME_DIR"
}

@test "BTASH-00: test harness initializes expected paths" {
	[[ -n "$PROJECT_ROOT" ]]
	[[ -n "$BASH_BIN" ]]
	[[ -n "$BTASH" ]]
	[[ -d "$FAKE_BIN" ]]
	[[ -d "$RUNTIME_DIR" ]]
}

create_fake_dtach() {
	cat >"$FAKE_BIN/dtach" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${BATS_TEST_TMPDIR}/dtach.log"
mode="${1:-}"
socket="${2:-}"
case "$mode" in
-c)
	: >"$socket"
	exit 0
	;;
-a | -p)
	[[ -e "$socket" ]] && exit 0
	exit 1
	;;
*)
	exit 0
	;;
esac
STUB
	chmod +x "$FAKE_BIN/dtach"
}

create_fake_dtach_runs_command() {
	cat >"$FAKE_BIN/dtach" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${BATS_TEST_TMPDIR}/dtach.log"
mode="${1:-}"
socket="${2:-}"
case "$mode" in
-c)
	: >"$socket"
	meta_path="${socket}.meta"
	rm -f "$meta_path"
	exit 0
	;;
-a | -p)
	[[ -e "$socket" ]] && exit 0
	exit 1
	;;
*)
	exit 0
	;;
esac
STUB
	chmod +x "$FAKE_BIN/dtach"
}

create_fake_dtach_creates_meta() {
	cat >"$FAKE_BIN/dtach" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${BATS_TEST_TMPDIR}/dtach.log"
mode="${1:-}"
socket="${2:-}"
case "$mode" in
-c)
	: >"$socket"
	meta_path="${socket}.meta"
	cwd="$PWD"
	created_at="$(date '+%Y-%m-%d %H:%M:%S')"
	session_pid=4242
	printf 'cwd=%q\ncreated_at=%q\nsession_pid=%q\n' \
		"$cwd" "$created_at" "$session_pid" >"$meta_path"
	exit 0
	;;
-a | -p)
	[[ -e "$socket" ]] && exit 0
	exit 1
	;;
*)
	exit 0
	;;
esac
STUB
	chmod +x "$FAKE_BIN/dtach"
}

create_fake_date() {
	cat >"$FAKE_BIN/date" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
+%Y-%m-%d\ %H:%M:%S) echo "2026-01-01 01:02:03" ;;
+%s) echo "1735689723" ;;
*) echo "1735689723" ;;
esac
STUB
	chmod +x "$FAKE_BIN/date"
}

create_fake_id() {
	cat >"$FAKE_BIN/id" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-u" ]]; then
	echo "4242"
	exit 0
fi
exit 1
STUB
	chmod +x "$FAKE_BIN/id"
}

start_live_session_pid() {
	sleep 300 &
	LIVE_SESSION_PID=$!
}

@test "BTASH-01 [D-01,D-12]: script-first entrypoint exists and is executable" {
	[[ -x "$BTASH" ]]
}

@test "BTASH-02 [D-02,D-09,D-10]: interactive menu shows create first and allows selection" {
	create_fake_dtach
	create_fake_date
	create_fake_id

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" -c "printf '1\n' | \"$BTASH\""

	assert_success
	assert_output --partial "Create new session"
	refute_output --partial "List sessions"
	refute_output --partial "Cleanup stale sessions"
	rm -rf "$RUNTIME_DIR/btash"

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" -c "printf '1\n' | \"$BTASH\" menu"

	assert_success
	assert_output --partial "Create new session"
}

@test "BTASH-03 [D-03,D-13]: new subcommand creates socket and metadata with cwd/timestamp" {
	create_fake_dtach_creates_meta
	create_fake_date
	create_fake_id

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" "$BTASH" new

	assert_success
	run ls "$RUNTIME_DIR/btash"/btash-*
	assert_success
	[[ "$output" =~ btash-[0-9a-f]{8} ]]
	run ls "$RUNTIME_DIR/btash"/btash-*.meta
	assert_success
	run grep -q "$PWD" "$RUNTIME_DIR/btash/"*.meta
	assert_success
	run grep -q "2026-01-01\\\\ 01:02:03" "$RUNTIME_DIR/btash/"*.meta
	assert_success
}

@test "BTASH-03b: new subcommand removes metadata after session shell exits" {
	create_fake_dtach_runs_command
	create_fake_date
	create_fake_id

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" "$BTASH" new

	assert_success
	run find "$RUNTIME_DIR/btash" -name '*.meta'
	assert_success
	[[ -z "$output" ]]
}

@test "BTASH-03c: existing stale session does not block creating a new session" {
	create_fake_dtach
	create_fake_date
	create_fake_id
	mkdir -p "$RUNTIME_DIR/btash"
	: >"$RUNTIME_DIR/btash/btash-deadbeef"

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" "$BTASH" new

	assert_success
	run "$BASH_BIN" -c "find \"$RUNTIME_DIR/btash\" -maxdepth 1 -name 'btash-*' | wc -l"
	assert_success
	[[ "$output" -ge 2 ]]
}

@test "BTASH-04 [D-04]: list subcommand shows newest-first with human metadata" {
	create_fake_dtach
	create_fake_date
	create_fake_id
	mkdir -p "$RUNTIME_DIR/btash"
	touch "$RUNTIME_DIR/btash/btash-0500" "$RUNTIME_DIR/btash/btash-1000" "$RUNTIME_DIR/btash/btash-2000"
	cat >"$RUNTIME_DIR/btash/btash-1000.meta" <<'META'
cwd="/tmp/one"
created_at="2024-01-01 01:01:01"
META
	cat >"$RUNTIME_DIR/btash/btash-2000.meta" <<'META'
cwd="/tmp/two"
created_at="2024-02-02 02:02:02"
META

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" "$BTASH" list

	assert_success
	assert_output --partial "/tmp/two"
	assert_output --partial "2024-02-02 02:02:02"
	refute_output --partial "unknown"
	first_line="$(printf '%s\n' "$output" | sed -n '1p')"
	[[ "$first_line" == *"btash-2000"* ]]
}

@test "BTASH-05 [D-06]: cleanup ignores orphaned metadata when no stale sockets exist" {
	create_fake_dtach
	create_fake_date
	create_fake_id
	mkdir -p "$RUNTIME_DIR/btash"
	touch "$RUNTIME_DIR/btash/btash-1000"
	start_live_session_pid
	cat >"$RUNTIME_DIR/btash/btash-1000.meta" <<'META'
cwd="/tmp/live"
created_at="2024-01-01 01:01:01"
META
	printf 'session_pid=%q\n' "$LIVE_SESSION_PID" >>"$RUNTIME_DIR/btash/btash-1000.meta"
	cat >"$RUNTIME_DIR/btash/btash-2000.meta" <<'META'
cwd="/tmp/dead"
created_at="2024-01-01 01:01:01"
META

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" -c "printf 'y\n' | \"$BTASH\" clean"

	assert_success
	[[ -f "$RUNTIME_DIR/btash/btash-1000" ]]
	[[ -f "$RUNTIME_DIR/btash/btash-1000.meta" ]]
	[[ -f "$RUNTIME_DIR/btash/btash-2000.meta" ]]
	assert_output --partial "No stale sessions found."
}

@test "BTASH-06 [D-07]: attach subcommand is rejected with non-zero exit" {
	run "$BASH_BIN" "$BTASH" attach btash-1234

	assert_failure
	assert_output --partial "menu"
}

@test "BTASH-07 [D-08]: attach is menu-driven and executes dtach -a with absolute socket path" {
	create_fake_dtach
	create_fake_date
	create_fake_id
	mkdir -p "$RUNTIME_DIR/btash"
	touch "$RUNTIME_DIR/btash/btash-1234"
	start_live_session_pid
	cat >"$RUNTIME_DIR/btash/btash-1234.meta" <<'META'
cwd="/tmp/attach"
created_at="2024-01-01 01:01:01"
META
	printf 'session_pid=%q\n' "$LIVE_SESSION_PID" >>"$RUNTIME_DIR/btash/btash-1234.meta"

	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" -c "printf '1\n' | \"$BTASH\""

	assert_success
	run grep -q -- "-a $RUNTIME_DIR/btash/btash-1234" "$BATS_TEST_TMPDIR/dtach.log"
	assert_success
}

@test "BTASH-08 [D-14]: invalid selection retries the menu loop" {
	create_fake_dtach
	create_fake_date
	create_fake_id
	mkdir -p "$RUNTIME_DIR/btash"
	run env PATH="$FAKE_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" -c "printf '9\n2\n' | \"$BTASH\""

	assert_success
	assert_output --partial "Create new session"
}

@test "BTASH-09 [D-11]: missing dtach fails with explicit error message" {
	run env PATH="$FAKE_BIN" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
		"$BASH_BIN" "$BTASH" new

	assert_failure
	assert_output --partial "dtach"
}
