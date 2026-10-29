class_name Command
extends RefCounted
## Base class for every player/AI action. Nothing changes WorldState except
## a Command that went through CommandBus.submit().
##
## Subclass contract:
##   validate(state) -> bool   read-only checks. On false, call _reject(reason).
##   execute(state)  -> CommandResult   applies the change. Runs only after validate() passed.

## CountryID of the actor. "" = system/debug.
var source_country: String = ""
## Snapshot of the game date at submit time. Set by CommandBus.
var timestamp: GameDate = null
## Why validate() returned false. Reset by CommandBus before every validate().
var failure_reason: String = ""


func get_command_name() -> String:
	return "Command"


func validate(_state) -> bool:
	return true


func execute(_state) -> CommandResult:
	return CommandResult.success()


## Use inside validate(): `return _reject("reason")`.
func _reject(reason: String) -> bool:
	failure_reason = reason
	return false
