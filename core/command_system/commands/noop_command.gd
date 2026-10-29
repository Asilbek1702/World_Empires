class_name NoopCommand
extends Command
## Does nothing. Exists to test the pipeline. valid = false makes validate() reject.

var valid: bool = true
var reject_reason: String = "Rejected by NoopCommand"


func get_command_name() -> String:
	return "Noop"


func validate(_state) -> bool:
	if not valid:
		return _reject(reject_reason)
	return true
