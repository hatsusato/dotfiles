#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME/.config/bash"
	export HOME="$FAKE_HOME"

	# Point to the main.sh in dotfiles (will be created in GREEN phase)
	MAIN_SH="$BATS_TEST_TMPDIR/../../../dotfiles/common/.config/bash/main.sh"
}

# ---------------------------------------------------------------------------
# Group 1: BASH-01 - Module discovery from conf.d/
# ---------------------------------------------------------------------------

# BASH-01a: main.sh sources all *.sh files from ~/.config/bash/conf.d/
@test "BASH-01a: main.sh sources all .sh files from conf.d/" {
	mkdir -p "$HOME/.config/bash/conf.d"
	cat > "$HOME/.config/bash/conf.d/05-first.sh" << 'EOF'
echo "FIRST" >> "$HOME/.config/bash/test-output.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-second.sh" << 'EOF'
echo "SECOND" >> "$HOME/.config/bash/test-output.log"
EOF
	cat > "$HOME/.config/bash/conf.d/15-third.sh" << 'EOF'
echo "THIRD" >> "$HOME/.config/bash/test-output.log"
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"

	assert [ -f "$HOME/.config/bash/test-output.log" ]
	grep -q "FIRST" "$HOME/.config/bash/test-output.log"
	grep -q "SECOND" "$HOME/.config/bash/test-output.log"
	grep -q "THIRD" "$HOME/.config/bash/test-output.log"
}

# BASH-01b: main.sh handles empty conf.d/ (no files to source)
@test "BASH-01b: main.sh handles empty conf.d/ directory" {
	mkdir -p "$HOME/.config/bash/conf.d"

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success
}

# BASH-01c: main.sh ignores non-.sh files in conf.d/
@test "BASH-01c: main.sh ignores non-.sh files in conf.d/" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-valid.sh" << 'EOF'
echo "VALID" >> "$HOME/.config/bash/test-output.log"
EOF

	echo "IGNORED_TXT" > "$HOME/.config/bash/conf.d/10-invalid.txt"
	echo "IGNORED_MD" > "$HOME/.config/bash/conf.d/15-readme.md"

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success

	assert [ -f "$HOME/.config/bash/test-output.log" ]
	grep -q "VALID" "$HOME/.config/bash/test-output.log"
}

# ---------------------------------------------------------------------------
# Group 2: BASH-02 - Module discovery from func.d/
# ---------------------------------------------------------------------------

# BASH-02a: main.sh sources all *.sh files from ~/.config/bash/func.d/
@test "BASH-02a: main.sh sources all .sh files from func.d/" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/func.d/05-func-first.sh" << 'EOF'
my_func_first() { echo "func first"; }
EOF
	cat > "$HOME/.config/bash/func.d/10-func-second.sh" << 'EOF'
my_func_second() { echo "func second"; }
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null && type my_func_first && type my_func_second"
	assert_success
	assert_output --partial "my_func_first is a function"
	assert_output --partial "my_func_second is a function"
}

# BASH-02b: main.sh handles empty func.d/
@test "BASH-02b: main.sh handles empty func.d/ directory" {
	mkdir -p "$HOME/.config/bash/func.d"

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success
}

# BASH-02c: main.sh ignores non-.sh files in func.d/
@test "BASH-02c: main.sh ignores non-.sh files in func.d/" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/func.d/05-valid-func.sh" << 'EOF'
valid_func() { echo "valid"; }
EOF

	echo "IGNORED" > "$HOME/.config/bash/func.d/10-file.txt"
	echo "IGNORED_MD" > "$HOME/.config/bash/func.d/15-doc.md"

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null && type valid_func"
	assert_success
	assert_output --partial "valid_func is a function"
}

# ---------------------------------------------------------------------------
# Group 3: BASH-03 - Alphabetical load order
# ---------------------------------------------------------------------------

# BASH-03a: conf.d/ modules load in alphabetical order
@test "BASH-03a: conf.d/ modules load in alphabetical order" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-first.sh" << 'EOF'
echo "05-first" >> "$HOME/.config/bash/load-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-second.sh" << 'EOF'
echo "10-second" >> "$HOME/.config/bash/load-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/20-third.sh" << 'EOF'
echo "20-third" >> "$HOME/.config/bash/load-order.log"
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success

	assert [ -f "$HOME/.config/bash/load-order.log" ]
	expected_order="05-first
10-second
20-third"
	actual_order=$(cat "$HOME/.config/bash/load-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-03b: func.d/ modules load in alphabetical order after conf.d/
@test "BASH-03b: func.d/ modules load in alphabetical order after conf.d/" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/conf.d/05-conf.sh" << 'EOF'
echo "conf-05" >> "$HOME/.config/bash/combined-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-conf.sh" << 'EOF'
echo "conf-10" >> "$HOME/.config/bash/combined-order.log"
EOF

	cat > "$HOME/.config/bash/func.d/05-func.sh" << 'EOF'
echo "func-05" >> "$HOME/.config/bash/combined-order.log"
EOF
	cat > "$HOME/.config/bash/func.d/10-func.sh" << 'EOF'
echo "func-10" >> "$HOME/.config/bash/combined-order.log"
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success

	assert [ -f "$HOME/.config/bash/combined-order.log" ]
	expected_order="conf-05
conf-10
func-05
func-10"
	actual_order=$(cat "$HOME/.config/bash/combined-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-03c: 2-digit prefix enables predictable insertion points
@test "BASH-03c: 2-digit prefix enables predictable load order (05/10/15/20)" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/20-zebra.sh" << 'EOF'
echo "20" >> "$HOME/.config/bash/numeric-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-apple.sh" << 'EOF'
echo "10" >> "$HOME/.config/bash/numeric-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/15-banana.sh" << 'EOF'
echo "15" >> "$HOME/.config/bash/numeric-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/05-yak.sh" << 'EOF'
echo "05" >> "$HOME/.config/bash/numeric-order.log"
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success

	assert [ -f "$HOME/.config/bash/numeric-order.log" ]
	expected_order="05
10
15
20"
	actual_order=$(cat "$HOME/.config/bash/numeric-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# ---------------------------------------------------------------------------
# Group 4: BASH-04 - Non-blocking error handling
# ---------------------------------------------------------------------------

# BASH-04a: One failing module does not prevent remaining modules from loading
@test "BASH-04a: failing module doesn't prevent other modules from loading" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-ok.sh" << 'EOF'
echo "OK-05" >> "$HOME/.config/bash/resilience.log"
EOF

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
this_is_a_syntax_error {
EOF

	cat > "$HOME/.config/bash/conf.d/15-ok.sh" << 'EOF'
echo "OK-15" >> "$HOME/.config/bash/resilience.log"
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null || true"

	assert [ -f "$HOME/.config/bash/resilience.log" ]
	grep -q "OK-05" "$HOME/.config/bash/resilience.log"
	grep -q "OK-15" "$HOME/.config/bash/resilience.log"
}

# BASH-04b: Module errors are logged via log_error with LOG_PREFIX=bashrc
@test "BASH-04b: module errors logged with LOG_PREFIX=bashrc" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
this_is_a_syntax_error {
EOF

	run bash -c "export HOME='$HOME' LOG_LEVEL=error; source '$MAIN_SH' 2>&1"

	assert_output --partial "bashrc"
}

# BASH-04c: Broken conf.d/ module doesn't block func.d/ loading
@test "BASH-04c: broken conf.d/ module doesn't block func.d/ loading" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/conf.d/05-bad.sh" << 'EOF'
syntax_error {
EOF

	cat > "$HOME/.config/bash/func.d/10-ok.sh" << 'EOF'
func_ok() { echo "OK"; }
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null || true; type func_ok 2>/dev/null && echo 'FOUND'"
	assert_output --partial "FOUND"
}

# BASH-04d: nullglob prevents error on missing directories
@test "BASH-04d: missing conf.d/ or func.d/ doesn't cause error" {
	mkdir -p "$HOME/.config/bash"

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success
}

# BASH-04e: main.sh exits with code 0 even if one module failed
@test "BASH-04e: main.sh exits with code 0 despite module failure" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null || true; exit 0"
	assert_success
}

# BASH-04f: Error message includes module filename
@test "BASH-04f: error message includes module filename" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "export HOME='$HOME' LOG_LEVEL=error; source '$MAIN_SH' 2>&1"

	assert_output --partial "10-bad"
}

# BASH-04g: Module success is silent (no log output at LOG_LEVEL=warn)
@test "BASH-04g: successful module sourcing is silent at LOG_LEVEL=warn" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-ok.sh" << 'EOF'
# This is fine
EOF

	run bash -c "export HOME='$HOME' LOG_LEVEL=warn; source '$MAIN_SH' 2>&1"
	assert_success

	assert [ -z "$output" ]
}

# BASH-04h: LOG_LEVEL=debug shows module load progress messages
@test "BASH-04h: LOG_LEVEL=debug shows module loading messages" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-ok.sh" << 'EOF'
# Valid module
EOF

	run bash -c "export HOME='$HOME' LOG_LEVEL=debug; source '$MAIN_SH' 2>&1"
	assert_success

	assert_output --partial "bashrc"
}

# BASH-04i: NO_COLOR=1 disables colors in error output
@test "BASH-04i: NO_COLOR=1 disables ANSI colors in errors" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "export HOME='$HOME' LOG_LEVEL=error NO_COLOR=1; source '$MAIN_SH' 2>&1"

	refute_output --partial $'\033['
}

# ---------------------------------------------------------------------------
# Group 5: Integration - conf.d/ and func.d/ together
# ---------------------------------------------------------------------------

# BASH-05a: Both conf.d/ and func.d/ directories created if missing
@test "BASH-05a: main.sh creates conf.d/ and func.d/ if missing" {
	mkdir -p "$HOME/.config/bash"

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success

	assert [ -d "$HOME/.config/bash/conf.d" ]
	assert [ -d "$HOME/.config/bash/func.d" ]
}

# BASH-05b: Large number of modules loads in correct order
@test "BASH-05b: many modules load in alphabetical order" {
	mkdir -p "$HOME/.config/bash/conf.d"

	for i in {05,10,15,20,25,30,35,40,45,50}; do
		cat > "$HOME/.config/bash/conf.d/${i}-module.sh" << EOF
echo "$i" >> "$HOME/.config/bash/many-order.log"
EOF
	done

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null"
	assert_success

	assert [ -f "$HOME/.config/bash/many-order.log" ]
	expected_order="05
10
15
20
25
30
35
40
45
50"
	actual_order=$(cat "$HOME/.config/bash/many-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-05c: Functions defined in func.d/ are available after sourcing
@test "BASH-05c: functions from func.d/ are callable after sourcing" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/func.d/05-utils.sh" << 'EOF'
util_a() { echo "A"; }
util_b() { echo "B"; }
EOF

	cat > "$HOME/.config/bash/func.d/10-helpers.sh" << 'EOF'
helper_x() { echo "X"; }
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null && util_a && util_b && helper_x"
	assert_success
	assert_output << 'EOF'
A
B
X
EOF
}

# BASH-05d: Environment variables from conf.d/ persist after main.sh
@test "BASH-05d: environment variables from conf.d/ persist after sourcing" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-env.sh" << 'EOF'
export MY_TEST_VAR="hello-from-module"
EOF

	run bash -c "export HOME='$HOME'; source '$MAIN_SH' 2>/dev/null && echo \$MY_TEST_VAR"
	assert_success
	assert_output "hello-from-module"
}
