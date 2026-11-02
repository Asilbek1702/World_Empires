extends "res://tests/test_base.gd"

const BusScript := preload("res://core/command_system/command_bus.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _tech(id: String, requires: Array) -> Technology:
	return Technology.from_dict({"id": id, "name": id.capitalize(), "cost": 1000,
			"requires": requires, "output_modifiers": {"science": 0.1}})


func _init() -> void:
	print("test_start_research_command")
	TechnologyCatalog.override_for_tests({"a": _tech("a", []), "b": _tech("b", []), "c": _tech("c", ["a"])})
	_test_success()
	_test_rejections()
	_test_switching_drops_progress()
	_test_every_country_may_research()
	_test_rules_agree_with_command()
	TechnologyCatalog.reset_cache()
	finish()


func _make() -> Dictionary:
	var ctx := {"bus": BusScript.new(), "state": StateScript.new(), "events": EventBusScript.new()}
	WorldBuilder.start_new_game(ctx["state"], 1)
	ctx["bus"].state = ctx["state"]
	ctx["bus"].event_bus = ctx["events"]
	ctx["bus"].verbose = false
	return ctx


func _dispose(ctx: Dictionary) -> void:
	for key in ctx:
		ctx[key].free()


func _first_country(state: Node) -> Country:
	var ids: Array = state.countries.keys()
	ids.sort()
	return state.countries[ids[0]]


func _test_success() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var country := _first_country(state)
	var changed: Array = []
	state.research_changed.connect(func(id): changed.append(id))
	var executed: Array = []
	ctx["events"].subscribe(Events.COMMAND_EXECUTED, func(p): executed.append(p))
	var result: CommandResult = ctx["bus"].submit(StartResearchCommand.new("a", country.id))
	check(result.ok, "starting a root technology succeeds")
	check(country.current_research == "a" and country.research_progress == 0.0, "the research is set, progress 0")
	check(changed == [country.id], "research_changed is emitted once")
	check(executed.size() == 1 and executed[0]["data"]["technology_id"] == "a", "the executed event carries the technology")
	check(WorldIntegrity.check(state).is_empty(), "the world stays consistent")
	_dispose(ctx)


func _test_rejections() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var country := _first_country(state)
	var before: Dictionary = state.to_dict()
	var signals: Array = []
	state.research_changed.connect(func(id): signals.append(id))
	var r: CommandResult = ctx["bus"].submit(StartResearchCommand.new("a", ""))
	check(not r.ok and "Unknown country" in r.reason, "no country rejected")
	r = ctx["bus"].submit(StartResearchCommand.new("a", "country_99999"))
	check(not r.ok and "Unknown country" in r.reason, "unknown country rejected")
	r = ctx["bus"].submit(StartResearchCommand.new("ghost", country.id))
	check(not r.ok and "Unknown technology" in r.reason, "unknown technology rejected")
	r = ctx["bus"].submit(StartResearchCommand.new("c", country.id))
	check(not r.ok and "Requires: A" in r.reason, "missing requirement rejected with its name (%s)" % r.reason)
	check(state.to_dict() == before and signals.is_empty(), "rejections change nothing and emit nothing")

	country.researched_technologies.append("a")
	r = ctx["bus"].submit(StartResearchCommand.new("a", country.id))
	check(not r.ok and "already researched" in r.reason, "a researched technology rejected")
	country.researched_technologies.clear()

	check(ctx["bus"].submit(StartResearchCommand.new("b", country.id)).ok, "b started")
	r = ctx["bus"].submit(StartResearchCommand.new("b", country.id))
	check(not r.ok and "already being researched" in r.reason, "the same research twice rejected")
	_dispose(ctx)


func _test_switching_drops_progress() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var country := _first_country(state)
	ctx["bus"].submit(StartResearchCommand.new("a", country.id))
	country.research_progress = 450.5
	var result: CommandResult = ctx["bus"].submit(StartResearchCommand.new("b", country.id))
	check(result.ok and country.current_research == "b" and country.research_progress == 0.0, "switching resets the progress")
	check(result.data["dropped_technology"] == "a" and result.data["lost_progress"] == 450.5, "the result reports what was lost")
	_dispose(ctx)


func _test_every_country_may_research() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var ids: Array = state.countries.keys()
	ids.sort()
	var ok := true
	for id in ids:
		if not ctx["bus"].submit(StartResearchCommand.new("a", id)).ok:
			ok = false
	check(ok, "every country can choose its own research")
	check((state.countries[ids[0]] as Country).current_research == "a" and (state.countries[ids[1]] as Country).current_research == "a", "each country keeps its own research")
	_dispose(ctx)


func _test_rules_agree_with_command() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var country := _first_country(state)
	check(ResearchRules.start_problem(state, country.id, "a") == "", "no problem reported for a valid choice")
	check(ResearchRules.start_problem(state, country.id, "c") != "", "a problem is reported for a locked technology")
	check(ResearchRules.start_problem(state, "country_99999", "a") != "", "a problem is reported for an unknown country")
	check(ResearchRules.start_problem(state, country.id, "ghost") != "", "a problem is reported for an unknown technology")
	_dispose(ctx)
