extends "res://tests/test_base.gd"

const BusScript := preload("res://core/command_system/command_bus.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


class ExecProbe extends Command:
	var allow: bool = true
	var executed: bool = false

	func get_command_name() -> String:
		return "ExecProbe"

	func validate(_state) -> bool:
		if not allow:
			return _reject("probe says no")
		return true

	func execute(state) -> CommandResult:
		executed = true
		state.rng_seed = 4242
		return CommandResult.success({"k": 1})


class ExecFails extends Command:
	func get_command_name() -> String:
		return "ExecFails"

	func execute(_state) -> CommandResult:
		return CommandResult.failure("boom")


class ExecNull extends Command:
	func get_command_name() -> String:
		return "ExecNull"

	func execute(_state) -> CommandResult:
		return null


class SilentReject extends Command:
	func get_command_name() -> String:
		return "SilentReject"

	func validate(_state) -> bool:
		return false


var _executed_events: Array = []
var _rejected_events: Array = []


func _init() -> void:
	print("test_command_system")
	_test_result_helpers()
	_test_noop_valid()
	_test_invalid_rejected_without_execute()
	_test_rejection_without_reason_gets_default()
	_test_valid_command_mutates_state()
	_test_debug_set_seed()
	_test_timestamp_is_snapshot()
	_test_executed_event_payload()
	_test_rejected_event_payload()
	_test_execute_failure()
	_test_execute_returning_null()
	_test_null_command()
	_test_resubmit_clears_old_reason()
	finish()


func _make() -> Dictionary:
	var ctx := {
		"bus": BusScript.new(),
		"state": StateScript.new(),
		"events": EventBusScript.new(),
	}
	ctx["bus"].state = ctx["state"]
	ctx["bus"].event_bus = ctx["events"]
	ctx["bus"].verbose = false
	_executed_events = []
	_rejected_events = []
	ctx["events"].subscribe(Events.COMMAND_EXECUTED, func(p): _executed_events.append(p))
	ctx["events"].subscribe(Events.COMMAND_REJECTED, func(p): _rejected_events.append(p))
	return ctx


func _dispose(ctx: Dictionary) -> void:
	for key in ctx:
		ctx[key].free()


func _test_result_helpers() -> void:
	var ok := CommandResult.success({"a": 1})
	check(ok.ok and ok.reason == "" and ok.data["a"] == 1, "success result")
	var bad := CommandResult.failure("nope")
	check(not bad.ok and bad.reason == "nope" and bad.data.is_empty(), "failure result")


func _test_noop_valid() -> void:
	var ctx := _make()
	var before: Dictionary = ctx["state"].to_dict()
	var result: CommandResult = ctx["bus"].submit(NoopCommand.new())
	check(result.ok, "valid Noop succeeds")
	check(ctx["state"].to_dict() == before, "Noop does not change WorldState")
	check(_executed_events.size() == 1 and _rejected_events.is_empty(), "Noop emits exactly one executed event")
	_dispose(ctx)


func _test_invalid_rejected_without_execute() -> void:
	var ctx := _make()
	var cmd := ExecProbe.new()
	cmd.allow = false
	var before: Dictionary = ctx["state"].to_dict()
	var result: CommandResult = ctx["bus"].submit(cmd)
	check(not result.ok, "invalid command is rejected")
	check(result.reason == "probe says no", "rejection carries the reason")
	check(not cmd.executed, "execute() is not called after a failed validate()")
	check(ctx["state"].to_dict() == before, "rejected command does not change WorldState")
	var noop := NoopCommand.new()
	noop.valid = false
	check(not ctx["bus"].submit(noop).ok, "Noop with valid=false is rejected")
	_dispose(ctx)


func _test_rejection_without_reason_gets_default() -> void:
	var ctx := _make()
	var result: CommandResult = ctx["bus"].submit(SilentReject.new())
	check(not result.ok and result.reason == "Command rejected", "default reason when validate gives none")
	_dispose(ctx)


func _test_valid_command_mutates_state() -> void:
	var ctx := _make()
	var cmd := ExecProbe.new()
	var result: CommandResult = ctx["bus"].submit(cmd)
	check(result.ok and cmd.executed, "valid command executes")
	check(ctx["state"].rng_seed == 4242, "execute changed WorldState")
	check(result.data["k"] == 1, "result data is returned")
	_dispose(ctx)


func _test_debug_set_seed() -> void:
	var ctx := _make()
	check(ctx["bus"].submit(DebugSetSeedCommand.new(777)).ok, "DebugSetSeed accepts 777")
	check(ctx["state"].rng_seed == 777, "seed set to 777")
	var result: CommandResult = ctx["bus"].submit(DebugSetSeedCommand.new(-1))
	check(not result.ok and result.reason == "Seed must not be negative", "DebugSetSeed rejects -1 with a reason")
	check(ctx["state"].rng_seed == 777, "seed unchanged after rejection")
	_dispose(ctx)


func _test_timestamp_is_snapshot() -> void:
	var ctx := _make()
	var cmd := NoopCommand.new()
	check(cmd.timestamp == null, "timestamp empty before submit")
	ctx["bus"].submit(cmd)
	ctx["state"].game_date.advance()
	check(str(cmd.timestamp) == "Spring 1000", "timestamp is the date at submit time")
	check(cmd.timestamp != ctx["state"].game_date, "timestamp is a copy, not the live date")
	_dispose(ctx)


func _test_executed_event_payload() -> void:
	var ctx := _make()
	ctx["bus"].submit(DebugSetSeedCommand.new(5, "country_00001"))
	var p: Dictionary = _executed_events[0]
	check(p["command_name"] == "DebugSetSeed", "payload has command_name")
	check(p["source_country"] == "country_00001", "payload has source_country")
	check(p["command"] is DebugSetSeedCommand, "payload has the command object")
	check(p["data"]["rng_seed"] == 5, "payload has result data")
	_dispose(ctx)


func _test_rejected_event_payload() -> void:
	var ctx := _make()
	ctx["bus"].submit(DebugSetSeedCommand.new(-3))
	check(_rejected_events.size() == 1 and _executed_events.is_empty(), "rejection emits exactly one rejected event")
	var p: Dictionary = _rejected_events[0]
	check(p["reason"] == "Seed must not be negative", "rejected payload has reason")
	check(p["stage"] == "validate", "rejected payload says stage = validate")
	_dispose(ctx)


func _test_execute_failure() -> void:
	var ctx := _make()
	var result: CommandResult = ctx["bus"].submit(ExecFails.new())
	check(not result.ok and result.reason == "boom", "execute failure is returned")
	check(_rejected_events.size() == 1 and _rejected_events[0]["stage"] == "execute", "execute failure emits rejected event with stage = execute")
	check(_executed_events.is_empty(), "no executed event after execute failure")
	_dispose(ctx)


func _test_execute_returning_null() -> void:
	var ctx := _make()
	var result: CommandResult = ctx["bus"].submit(ExecNull.new())
	check(not result.ok, "execute() returning null is treated as failure")
	check(_rejected_events.size() == 1, "null result emits a rejected event")
	_dispose(ctx)


func _test_null_command() -> void:
	var ctx := _make()
	var result: CommandResult = ctx["bus"].submit(null)
	check(not result.ok, "null command is rejected without crashing")
	check(_executed_events.is_empty() and _rejected_events.is_empty(), "null command emits no events")
	_dispose(ctx)


func _test_resubmit_clears_old_reason() -> void:
	var ctx := _make()
	var cmd := ExecProbe.new()
	cmd.allow = false
	ctx["bus"].submit(cmd)
	check(cmd.failure_reason == "probe says no", "failure_reason is set after rejection")
	cmd.allow = true
	var result: CommandResult = ctx["bus"].submit(cmd)
	check(result.ok and cmd.failure_reason == "", "resubmitting a fixed command succeeds and clears the old reason")
	_dispose(ctx)
