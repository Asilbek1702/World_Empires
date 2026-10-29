#!/usr/bin/env bash
# Runs every unit test headless. Usage: GODOT=godot4 ./tests/run_all.sh
# Run from the project root. Exit code 1 if any test fails.
#
# Godot exits with code 0 even when a test script fails to compile, so the
# exit code alone cannot be trusted. A test passes only if its output has
# a "N checks, 0 failed" line and no SCRIPT ERROR / "Failed to load" line.
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import > /dev/null 2>&1
fail=0
for t in tests/unit/test_*.gd; do
  output=$("$GODOT" --headless --path . --script "res://$t" 2>&1)
  code=$?
  echo "$output"
  if [ $code -ne 0 ] \
      || ! echo "$output" | grep -qE "[0-9]+ checks, 0 failed" \
      || echo "$output" | grep -qE "SCRIPT ERROR|Failed to load script"; then
    echo ">>> FAILED: $t"
    fail=1
  fi
done
if [ $fail -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit $fail
