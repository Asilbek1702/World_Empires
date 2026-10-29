extends Node
## Autoload "CommandBus". The only way to change the world.
## submit(): validate -> execute -> notify via EventBus.
## Events: Events.COMMAND_EXECUTED, Events.COMMAND_REJECTED.
## Payload keys: command, command_name, source_country, plus
##   executed: data      rejected: reason, stage ("validate" or "execute")
## Iter 4: execution is immediate. Season-time resolution comes with the systems.

## WorldState and EventBus nodes. Resolved from /root on first use. Tests inject their own.
var state: Node = null
var event_bus: Node = null
var verbose: bool = true


func submit(cmd: Command) -> CommandResult:
	if cmd == null:
		return CommandResult.failure("Null command")
	var world := _get_state()
	if world == null:
		return _reject(cmd, "validate", "WorldState is not available")

	cmd.timestamp = world.game_date.copy()
	cmd.failure_reason = ""
	if not cmd.validate(world):
		var reason := cmd.failure_reason if cmd.failure_reason != "" else "Command rejected"
		return _reject(cmd, "validate", reason)

	var result := cmd.execute(world)
	if result == null:
		return _reject(cmd, "execute", "execute() returned no result")
	if not result.ok:
		var failure_text := result.reason if result.reason != "" else "Command failed"
		return _reject(cmd, "execute", failure_text)

	if verbose:
		print("[Command] OK       %s | %s" % [cmd.timestamp, cmd.get_command_name()])
	_notify(Events.COMMAND_EXECUTED, cmd, {"data": result.data})
	return result


func _reject(cmd: Command, stage: String, reason: String) -> CommandResult:
	if verbose:
		print("[Command] REJECTED %s | %s: %s (%s)" % [
			cmd.timestamp, cmd.get_command_name(), reason, stage])
	_notify(Events.COMMAND_REJECTED, cmd, {"reason": reason, "stage": stage})
	return CommandResult.failure(reason)


func _notify(event_name: StringName, cmd: Command, extra: Dictionary) -> void:
	var events := _get_event_bus()
	if events == null:
		return
	var payload := {
		"command": cmd,
		"command_name": cmd.get_command_name(),
		"source_country": cmd.source_country,
	}
	payload.merge(extra)
	events.emit(event_name, payload)


func _get_state() -> Node:
	if state == null:
		state = get_node_or_null("/root/WorldState")
	return state


func _get_event_bus() -> Node:
	if event_bus == null:
		event_bus = get_node_or_null("/root/EventBus")
	return event_bus
