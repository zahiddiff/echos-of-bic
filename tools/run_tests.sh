#!/usr/bin/env bash
# Runs every headless test suite. Usage: tools/run_tests.sh [path-to-godot]
set -u
GODOT="${1:-godot}"
fail=0

run() {
	local name="${*: -1}"
	local out line
	out=$(timeout 400 "$GODOT" --headless --path . "$@" 2>&1)
	line=$(printf '%s\n' "$out" | grep -E "PASSED|FAILED" | tail -1)
	printf '%-20s %s\n' "$(basename "$name" | sed 's/\.[^.]*$//')" "${line:-NO RESULT}"
	if [[ "$line" != *PASSED* ]]; then
		printf '%s\n' "$out" | grep -E "FAIL |SCRIPT ERROR" | head -20
		fail=1
	fi
}

for t in validate_setup smoke_test rulebook_test queue_test; do
	run --script "res://tools/$t.gd"
done
for t in building_test flow_test desk_test dialogue_test consequence_test onboarding_test \
		environment_test character_test shift_end_test playtest_test balance_sim; do
	run "res://tools/$t.tscn"
done
exit $fail
