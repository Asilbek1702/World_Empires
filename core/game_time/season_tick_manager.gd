extends Node
## Autoload "SeasonTickManager".
## advance_season() runs one season:
##   for each phase of TickOrder, in order: call on_season_tick() of its systems
##   then advance the date and publish Events.NEW_SEASON.
## The date lives in WorldState (single source of truth).
## Systems see the season that is ENDING; NEW_SEASON carries the new date.

## WorldState and EventBus nodes. Resolved from /root on first use. Tests inject their own.
var state: Node = null
var event_bus: Node = null

## One summary line per tick.
var verbose: bool = true
## Also print every phase with its systems (debug).
var trace: bool = false

var current_date: GameDate:
	get:
		var s := _get_state()
		return s.game_date if s != null else null

var _all: Array[IGameSystem] = []
var _phases: Array = []  # index = TickOrder.Phase, value = Array of IGameSystem
var _ticking: bool = false


func _init() -> void:
	for i in TickOrder.Phase.size():
		_phases.append([])


## Returns false (and registers nothing) if the system is null, already registered,
## or does not name a valid phase.
func register_system(system: IGameSystem) -> bool:
	if system == null:
		return false
	if system in _all:
		push_warning("System already registered: %s" % system.get_system_name())
		return false
	var phase := system.get_tick_phase()
	if not TickOrder.is_valid(phase):
		push_warning("System '%s' has no valid tick phase (%d), not registered" % [
			system.get_system_name(), phase])
		return false
	_all.append(system)
	(_phases[phase] as Array).append(system)
	return true


func unregister_system(system: IGameSystem) -> void:
	if not (system in _all):
		return
	_all.erase(system)
	for phase_systems in _phases:
		(phase_systems as Array).erase(system)


func get_system_count() -> int:
	return _all.size()


func get_systems_in_phase(phase: int) -> Array[IGameSystem]:
	var out: Array[IGameSystem] = []
	if TickOrder.is_valid(phase):
		for system in (_phases[phase] as Array):
			out.append(system)
	return out


func is_ticking() -> bool:
	return _ticking


## One line per phase: "05 PRODUCTION: ProductionSystem, ..." or "-" when empty.
func describe_pipeline() -> Array[String]:
	var lines: Array[String] = []
	for phase in TickOrder.Phase.size():
		var names: Array[String] = []
		for system in (_phases[phase] as Array):
			names.append((system as IGameSystem).get_system_name())
		lines.append("%02d %s: %s" % [
			phase + 1, TickOrder.phase_name(phase), ", ".join(names) if not names.is_empty() else "-"])
	return lines


## Runs all phases for the current season, then moves the date forward.
## A call made while a tick is already running is ignored.
func advance_season() -> void:
	if _ticking:
		push_warning("advance_season() called during a tick, ignored")
		return
	var world := _get_state()
	if world == null:
		push_error("SeasonTickManager: WorldState not found")
		return

	_ticking = true
	var date: GameDate = world.game_date
	if verbose:
		print("[Tick] %s (turn %d) - %d systems" % [date, date.turn_number, _all.size()])
	for phase in TickOrder.Phase.size():
		var phase_systems: Array = (_phases[phase] as Array).duplicate()
		if trace:
			print("[Tick]   %02d %s (%d systems)" % [
				phase + 1, TickOrder.phase_name(phase), phase_systems.size()])
		for system in phase_systems:
			(system as IGameSystem).on_season_tick(world)
	date.advance()
	_ticking = false
	_publish_new_season(date)


func _publish_new_season(date: GameDate) -> void:
	var events := _get_event_bus()
	if events == null:
		return
	events.emit(Events.NEW_SEASON, {
		"date": date.copy(),
		"year": date.year,
		"season": int(date.season),
		"season_name": date.season_name(),
		"turn_number": date.turn_number,
	})


func _get_state() -> Node:
	if state == null:
		state = get_node_or_null("/root/WorldState")
	return state


func _get_event_bus() -> Node:
	if event_bus == null:
		event_bus = get_node_or_null("/root/EventBus")
	return event_bus
