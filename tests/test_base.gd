extends SceneTree
## Minimal headless test base. Run a test with:
##   godot --headless --path . --script res://tests/unit/<test_file>.gd
## Exit code 0 = all checks passed, 1 = at least one failed.

var _failures: int = 0
var _checks: int = 0


func check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  PASS: %s" % message)
	else:
		_failures += 1
		printerr("  FAIL: %s" % message)


func finish() -> void:
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
