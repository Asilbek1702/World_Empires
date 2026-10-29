extends "res://tests/test_base.gd"

const ManagerScript := preload("res://core/game_time/season_tick_manager.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


## Records (label, phase, date at call time) into a shared log.
class MockSystem extends IGameSystem:
	var label: String = ""
	var phase: int = TickOrder.Phase.ECONOMY
	var log: Array = []
	var last_state = null
	var tick_count: int = 0

	func get_system_name() -> String:
		return label

	func get_tick_phase() -> int:
		return phase

	func on_season_tick(state) -> void:
		tick_count += 1
		last_state = state
		log.append({"label": label, "phase": phase, "date": str(state.game_date)})


class NoPhaseSystem extends IGameSystem:
	func get_system_name() -> String:
		return "NoPhase"


class ReentrantSystem extends IGameSystem:
	var manager: Node = null

	func get_system_name() -> String:
		return "Reentrant"

	func get_tick_phase() -> int:
		return TickOrder.Phase.AI

	func on_season_tick(_state) -> void:
		manager.advance_season()


func _init() -> void:
	print("test_season_tick_manager")
	_test_advance_moves_date()
	_test_date_lives_in_world_state()
	_test_systems_run_in_phase_order()
	_test_same_phase_keeps_registration_order()
	_test_every_phase_runs_once_in_order()
	_test_systems_receive_world_state_and_old_date()
	_test_missing_or_invalid_phase_rejected()
	_test_duplicate_registration_rejected()
	_test_unregister()
	_test_new_season_event()
	_test_event_comes_after_all_systems()
	_test_reentrant_advance_is_ignored()
	_test_describe_pipeline()
	finish()


func _make() -> Dictionary:
	var ctx := {"m": ManagerScript.new(), "state": StateScript.new(), "events": EventBusScript.new()}
	ctx["m"].state = ctx["state"]
	ctx["m"].event_bus = ctx["events"]
	ctx["m"].verbose = false
	return ctx


func _dispose(ctx: Dictionary) -> void:
	for key in ctx:
		ctx[key].free()


func _mock(label: String, phase: int, shared_log: Array) -> MockSystem:
	var s := MockSystem.new()
	s.label = label
	s.phase = phase
	s.log = shared_log
	return s


func _test_advance_moves_date() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	m.advance_season()
	check(m.current_date.season == GameDate.Season.SUMMER, "advance_season moves Spring -> Summer")
	check(m.current_date.turn_number == 2, "advance_season increments turn")
	_dispose(ctx)


func _test_date_lives_in_world_state() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	m.advance_season()
	check(m.state.game_date.turn_number == 2, "WorldState.game_date is the advanced date")
	check(m.current_date == m.state.game_date, "current_date is WorldState.game_date")
	m.state.new_game(5, GameDate.new(1939, GameDate.Season.WINTER, 40))
	m.advance_season()
	check(str(m.current_date) == "Spring 1940", "manager follows a replaced WorldState date")
	_dispose(ctx)


func _test_systems_run_in_phase_order() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var log: Array = []
	# registered in the WRONG order on purpose
	m.register_system(_mock("ai", TickOrder.Phase.AI, log))
	m.register_system(_mock("economy", TickOrder.Phase.ECONOMY, log))
	m.register_system(_mock("movement", TickOrder.Phase.MOVEMENT, log))
	m.advance_season()
	var labels: Array = log.map(func(e): return e["label"])
	check(labels == ["movement", "economy", "ai"], "systems run in phase order, not registration order")
	_dispose(ctx)


func _test_same_phase_keeps_registration_order() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var log: Array = []
	m.register_system(_mock("A", TickOrder.Phase.SUPPLY, log))
	m.register_system(_mock("B", TickOrder.Phase.SUPPLY, log))
	m.register_system(_mock("C", TickOrder.Phase.SUPPLY, log))
	m.advance_season()
	check(log.map(func(e): return e["label"]) == ["A", "B", "C"], "inside one phase: registration order")
	_dispose(ctx)


func _test_every_phase_runs_once_in_order() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var log: Array = []
	var phases: Array = range(TickOrder.Phase.size())
	phases.reverse()
	for phase in phases:  # registered from the last phase to the first
		m.register_system(_mock(TickOrder.phase_name(phase), phase, log))
	m.advance_season()
	var expected: Array = []
	for phase in TickOrder.Phase.size():
		expected.append(TickOrder.phase_name(phase))
	check(log.map(func(e): return e["label"]) == expected, "one system per phase runs exactly in the specification order")
	check(log.size() == TickOrder.Phase.size(), "every phase ran exactly once")
	m.advance_season()
	check(log.size() == 2 * TickOrder.Phase.size(), "the next season runs every phase again")
	_dispose(ctx)


func _test_systems_receive_world_state_and_old_date() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var log: Array = []
	var first := _mock("first", TickOrder.Phase.VALIDATE_ACTIONS, log)
	var last := _mock("last", TickOrder.Phase.SAVE_CHECK, log)
	m.register_system(first)
	m.register_system(last)
	m.advance_season()
	check(first.last_state == m.state, "systems receive the WorldState")
	check(log[0]["date"] == "Spring 1000" and log[1]["date"] == "Spring 1000", "all phases see the season that is ending")
	check(str(m.current_date) == "Summer 1000", "the date advanced after the last phase")
	_dispose(ctx)


func _test_missing_or_invalid_phase_rejected() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	check(not m.register_system(NoPhaseSystem.new()), "system without a phase is rejected")
	var bad := _mock("bad", 99, [])
	check(not m.register_system(bad), "system with an out of range phase is rejected")
	check(not m.register_system(null), "null system is rejected")
	check(m.get_system_count() == 0, "rejected systems are not registered")
	m.advance_season()
	check(bad.tick_count == 0, "rejected systems are never called")
	_dispose(ctx)


func _test_duplicate_registration_rejected() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var s := _mock("dup", TickOrder.Phase.ECONOMY, [])
	check(m.register_system(s), "first registration succeeds")
	check(not m.register_system(s), "second registration is rejected")
	check(m.get_system_count() == 1, "a system counts once")
	m.advance_season()
	check(s.tick_count == 1, "a duplicate does not tick twice")
	_dispose(ctx)


func _test_unregister() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var s := _mock("gone", TickOrder.Phase.POPULATION, [])
	m.register_system(s)
	m.unregister_system(s)
	m.unregister_system(s)
	check(m.get_system_count() == 0 and m.get_systems_in_phase(TickOrder.Phase.POPULATION).is_empty(), "unregistered system is gone")
	m.advance_season()
	check(s.tick_count == 0, "unregistered system is not called")
	_dispose(ctx)


func _test_new_season_event() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var received: Array = []
	ctx["events"].subscribe(Events.NEW_SEASON, func(p): received.append(p))
	m.advance_season()
	check(received.size() == 1, "NEW_SEASON is published once per season")
	var p: Dictionary = received[0]
	check(p["season_name"] == "Summer" and p["year"] == 1000 and p["turn_number"] == 2, "payload carries the NEW date")
	check(p["season"] == GameDate.Season.SUMMER, "payload has the season index")
	check(str(p["date"]) == "Summer 1000", "payload has a date object")
	p["date"].advance()
	check(str(m.current_date) == "Summer 1000", "the payload date is a copy")
	m.advance_season()
	check(received.size() == 2, "and again for the next season")
	_dispose(ctx)


func _test_event_comes_after_all_systems() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var log: Array = []
	m.register_system(_mock("last_phase", TickOrder.Phase.SAVE_CHECK, log))
	ctx["events"].subscribe(Events.NEW_SEASON, func(_p): log.append({"label": "EVENT", "date": str(m.current_date)}))
	m.advance_season()
	check(log.map(func(e): return e["label"]) == ["last_phase", "EVENT"], "NEW_SEASON comes after the last phase")
	check(log[1]["date"] == "Summer 1000", "the date is already new when NEW_SEASON is published")
	_dispose(ctx)


func _test_reentrant_advance_is_ignored() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var s := ReentrantSystem.new()
	s.manager = m
	m.register_system(s)
	check(not m.is_ticking(), "not ticking before")
	m.advance_season()
	check(m.current_date.turn_number == 2, "a nested advance_season() is ignored (exactly one season passed)")
	check(not m.is_ticking(), "not ticking after")
	_dispose(ctx)


func _test_describe_pipeline() -> void:
	var ctx := _make()
	var m: Node = ctx["m"]
	var lines: Array[String] = m.describe_pipeline()
	check(lines.size() == TickOrder.Phase.size(), "one line per phase")
	check(lines[0] == "01 VALIDATE_ACTIONS: -", "an empty phase shows a dash")
	m.register_system(_mock("EcoA", TickOrder.Phase.ECONOMY, []))
	m.register_system(_mock("EcoB", TickOrder.Phase.ECONOMY, []))
	lines = m.describe_pipeline()
	check(lines[6] == "07 ECONOMY: EcoA, EcoB", "systems are listed by name in their phase")
	_dispose(ctx)
