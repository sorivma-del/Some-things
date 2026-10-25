#!/usr/bin/env bash
# Runs every headless test and prints one line per suite. Usage: tools/tests/run_all.sh
# (from GreyFord/). Exit code is non-zero if any suite fails.
cd "$(dirname "$0")/../.."
status=0
for t in combat enemy trade fight world debug horse open_world world_performance raid courtyard controller shrine_episode combat_audio; do
	out=$(timeout 600 godot --headless -s "res://tools/tests/${t}_test.gd" -- --skip-intro 2>&1)
	echo "$out" | grep -E "^FAIL|SCRIPT ERROR"
	line=$(echo "$out" | grep -E "^[a-z_]+ test: [0-9]+ failure")
	echo "${line:-$t test: did not finish}"
	[[ "$line" == *" 0 failure"* ]] || status=1
done
exit $status
