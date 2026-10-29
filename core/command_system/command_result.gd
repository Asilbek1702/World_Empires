class_name CommandResult
extends RefCounted
## Outcome of a command. Build it with CommandResult.success() / failure().

var ok: bool = true
var reason: String = ""
var data: Dictionary = {}


static func success(p_data: Dictionary = {}) -> CommandResult:
	var result := CommandResult.new()
	result.ok = true
	result.data = p_data
	return result


static func failure(p_reason: String) -> CommandResult:
	var result := CommandResult.new()
	result.ok = false
	result.reason = p_reason
	return result
