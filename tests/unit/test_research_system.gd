extends "res://tests/test_base.gd"

const ManagerScript := preload("res://core/game_time/season_tick_manager.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _init() -> void:
	print("test_research_system")
	TechnologyCatalog.reset_cache()
	_test_phase_and_registration()
	_test_idle_world_is_unchanged()
	_test_progress_and_completion()
	_test_signals_fire_once()
	_test_effect_on_the_economy()
	_test_other_countries_unaffected()
	_test_unknown_research_is_dropped()
	_test_deterministic()
	_test_survives_save_and_load()
	_test_integrity_rules()
	TechnologyCatalog.reset_cache()
	finish()


func _world() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _country(state: Node, index: int = 0) -> Country:
	var ids: Array = state.countries.keys()
	ids.sort()
	return state.countries[ids[index]]


func _science(state: Node, country: Country) -> float:
	return EconomyModel.country_report(country, state.regions, state.cities).get_output(ResourceTypes.Type.SCIENCE)


func _tech(id: String, requires: Array, modifiers: Dictionary, cost: int) -> Technology:
	return Technology.from_dict({"id": id, "name": id.capitalize(), "cost": cost,
			"requires": requires, "output_modifiers": modifiers})


func _test_phase_and_registration() -> void:
	check(ResearchSystem.new().get_tick_phase() == TickOrder.Phase.WORLD_UPDATE, "the system runs in the WORLD_UPDATE phase")
	check(TickOrder.Phase.ECONOMY < TickOrder.Phase.WORLD_UPDATE, "research runs after the economy")
	var manager = ManagerScript.new()
	GameSystems.register_all(manager)
	check(manager.get_systems_in_phase(TickOrder.Phase.WORLD_UPDATE).size() == 1, "register_all registers the research system")
	check(manager.get_systems_in_phase(TickOrder.Phase.ECONOMY).size() == 1, "the economy phase still has one system")
	manager.free()


func _test_idle_world_is_unchanged() -> void:
	var s = _world()
	var before: Dictionary = s.to_dict()
	for season in 5:
		ResearchSystem.new().on_season_tick(s)
	check(s.to_dict() == before, "countries without research do not change")
	s.free()


func _test_progress_and_completion() -> void:
	var s = _world()
	var country := _country(s)
	var science := _science(s, country)
	check(science > 1.0, "the country makes science (%.1f)" % science)
	var cost := int(science * 2.5) + 1
	TechnologyCatalog.override_for_tests({"a": _tech("a", [], {}, cost)})
	country.current_research = "a"
	var system := ResearchSystem.new()
	system.on_season_tick(s)
	check(_near(country.research_progress, science), "season 1: progress = one season of science")
	system.on_season_tick(s)
	check(_near(country.research_progress, 2.0 * science) and country.researched_technologies.is_empty(), "season 2: still researching")
	system.on_season_tick(s)
	check(country.researched_technologies == ["a"], "season 3: the technology is learned")
	check(country.current_research == "" and country.research_progress == 0.0, "the research slot is empty, the surplus is lost")
	var snapshot: Dictionary = s.to_dict()
	system.on_season_tick(s)
	check(s.to_dict() == snapshot, "afterwards nothing changes (no research chosen)")
	check(WorldIntegrity.check(s).is_empty(), "the world stays consistent")
	s.free()
	TechnologyCatalog.reset_cache()


func _test_signals_fire_once() -> void:
	var s = _world()
	var country := _country(s)
	TechnologyCatalog.override_for_tests({"a": _tech("a", [], {}, 1)})
	country.current_research = "a"
	var done: Array = []
	var changed: Array = []
	s.technology_researched.connect(func(c, t): done.append([c, t]))
	s.research_changed.connect(func(c): changed.append(c))
	for season in 4:
		ResearchSystem.new().on_season_tick(s)
	check(done == [[country.id, "a"]], "technology_researched fires exactly once")
	check(changed == [country.id], "research_changed fires once, on completion")
	s.free()
	TechnologyCatalog.reset_cache()


func _test_effect_on_the_economy() -> void:
	var s = _world()
	var country := _country(s)
	TechnologyCatalog.override_for_tests({"a": _tech("a", [], {"science": 0.2}, 1)})
	var before := _science(s, country)
	country.current_research = "a"
	ResearchSystem.new().on_season_tick(s)
	var after := _science(s, country)
	check(absf(after - before * 1.2) < 0.0001, "+20%% science from the next season (%.2f -> %.2f)" % [before, after])
	var report := EconomyModel.country_report(country, s.regions, s.cities)
	check(absf(report.gold_income() - EconomyModel.country_report(country, s.regions).gold_income()) < 0.0001, "with and without cities agree on gold")
	s.free()
	TechnologyCatalog.reset_cache()


func _test_other_countries_unaffected() -> void:
	var s = _world()
	var first := _country(s, 0)
	var second := _country(s, 1)
	TechnologyCatalog.override_for_tests({"a": _tech("a", [], {"gold": 0.5}, 1)})
	var other_before := EconomyModel.country_report(second, s.regions, s.cities).output
	first.current_research = "a"
	ResearchSystem.new().on_season_tick(s)
	check(EconomyModel.country_report(second, s.regions, s.cities).output == other_before, "a technology of one country does not change another")
	check(second.researched_technologies.is_empty(), "the other country learned nothing")
	s.free()
	TechnologyCatalog.reset_cache()


func _test_unknown_research_is_dropped() -> void:
	var s = _world()
	var country := _country(s)
	country.current_research = "ghost"
	country.research_progress = 12.5
	ResearchSystem.new().on_season_tick(s)
	check(country.current_research == "" and country.research_progress == 0.0, "research of an unknown technology is dropped")
	s.free()


func _test_deterministic() -> void:
	var a = _world()
	var b = _world()
	_country(a).current_research = "irrigation"
	_country(b).current_research = "irrigation"
	for season in 30:
		ResearchSystem.new().on_season_tick(a)
		ResearchSystem.new().on_season_tick(b)
	check(a.to_dict() == b.to_dict(), "two worlds give identical research after 30 seasons")
	check(_country(a).researched_technologies.has("irrigation"), "the shipped irrigation is learned within 30 seasons")
	a.free()
	b.free()


func _test_survives_save_and_load() -> void:
	var a = _world()
	var country := _country(a)
	country.current_research = "writing"
	var system := ResearchSystem.new()
	system.on_season_tick(a)
	system.on_season_tick(a)
	check(country.research_progress > 0.0, "research is in progress")
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict()))) == OK, "a world with a running research loads")
	var loaded: Country = b.countries[country.id]
	check(loaded.current_research == "writing" and loaded.research_progress == country.research_progress, "research and progress are exactly the same")
	for season in 40:
		system.on_season_tick(a)
		system.on_season_tick(b)
	check(a.to_dict() == b.to_dict(), "the loaded world stays identical to the original")
	check(WorldIntegrity.check(b).is_empty(), "the loaded world is consistent")
	a.free()
	b.free()


func _test_integrity_rules() -> void:
	var s = _world()
	var country := _country(s)
	var catalog := TechnologyCatalog.get_all()
	check(WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "a fresh world has consistent technologies")

	country.researched_technologies.append("iron_tools")
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "a technology without its requirement is caught")
	country.researched_technologies.clear()
	country.researched_technologies.append("ghost")
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "an unknown technology is caught")
	country.researched_technologies.clear()
	country.researched_technologies.append("irrigation")
	country.researched_technologies.append("irrigation")
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "a technology twice is caught")
	country.researched_technologies.clear()

	country.current_research = "iron_tools"
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "a locked current research is caught")
	country.current_research = "ghost"
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "an unknown current research is caught")
	country.current_research = "irrigation"
	country.research_progress = 100.0
	check(WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "a valid running research is consistent")
	country.research_progress = float((catalog["irrigation"] as Technology).cost)
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "progress at the cost is caught")
	country.research_progress = 5.0
	country.current_research = ""
	check(not WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "progress without a research is caught")
	country.research_progress = 0.0
	check(WorldIntegrity.check_technologies(s.countries, catalog).is_empty(), "back to consistent")
	s.free()
