extends "res://tests/test_base.gd"

const ManagerScript := preload("res://core/game_time/season_tick_manager.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _init() -> void:
	print("test_population_system")
	_test_phase_and_registration()
	_test_one_tick_matches_the_model()
	_test_only_population_changes()
	_test_forty_seasons()
	_test_deterministic()
	_test_zero_region_stays_empty()
	_test_stats()
	_test_through_the_tick_manager()
	_test_survives_save_and_load()
	finish()


func _world() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _test_phase_and_registration() -> void:
	var system := PopulationSystem.new()
	check(system.get_tick_phase() == TickOrder.Phase.POPULATION, "the system runs in the POPULATION phase")
	check(TickOrder.Phase.POPULATION < TickOrder.Phase.ECONOMY, "population runs before the economy")
	var manager = ManagerScript.new()
	GameSystems.register_all(manager)
	check(manager.get_systems_in_phase(TickOrder.Phase.POPULATION).size() == 1, "register_all registers the population system")
	manager.free()


func _test_one_tick_matches_the_model() -> void:
	var s = _world()
	var before := {}
	for id in s.regions:
		before[id] = (s.regions[id] as Region).population
	PopulationSystem.new().on_season_tick(s)
	var mismatches := 0
	var grew := 0
	for id in s.regions:
		var region: Region = s.regions[id]
		var expected := PopulationModel.next_population(before[id], PopulationConfig.capacity(region))
		if region.population != expected:
			mismatches += 1
		if region.population > before[id]:
			grew += 1
	check(mismatches == 0, "every region changed exactly as the model says")
	check(grew == s.regions.size(), "every region grew in the first season")
	s.free()


func _test_only_population_changes() -> void:
	var s = _world()
	var owners := {}
	for id in s.regions:
		owners[id] = (s.regions[id] as Region).country_id
	var countries_before: Dictionary = s.to_dict()["countries"]
	PopulationSystem.new().on_season_tick(s)
	var same_owners := true
	for id in s.regions:
		if (s.regions[id] as Region).country_id != owners[id]:
			same_owners = false
	check(same_owners, "region owners are untouched")
	check(s.to_dict()["countries"] == countries_before, "countries are untouched")
	check(WorldIntegrity.check(s).is_empty(), "the world stays consistent")
	s.free()


func _test_forty_seasons() -> void:
	var s = _world()
	var system := PopulationSystem.new()
	var start_total := PopulationStats.world_total(s.regions)
	var ok_bounds := true
	var monotone := true
	var previous := start_total
	for season in 40:
		system.on_season_tick(s)
		var total := PopulationStats.world_total(s.regions)
		if total < previous:
			monotone = false
		previous = total
		for id in s.regions:
			var region: Region = s.regions[id]
			if region.population < 0 or region.population > PopulationConfig.capacity(region):
				ok_bounds = false
	var growth := float(previous - start_total) / float(start_total)
	check(ok_bounds, "after 40 seasons no region is negative or above capacity")
	check(monotone, "the world population never fell")
	check(growth > 0.05 and growth < 0.40, "40 seasons (10 years) grow the world by 5-40%% (got %.1f%%)" % (growth * 100.0))
	s.free()


func _test_deterministic() -> void:
	var a = _world()
	var b = _world()
	var system := PopulationSystem.new()
	for season in 25:
		system.on_season_tick(a)
		system.on_season_tick(b)
	check(a.to_dict() == b.to_dict(), "two worlds give identical populations after 25 seasons")
	a.free()
	b.free()


func _test_zero_region_stays_empty() -> void:
	var s = _world()
	var id: String = s.regions.keys()[0]
	(s.regions[id] as Region).population = 0
	for season in 10:
		PopulationSystem.new().on_season_tick(s)
	check((s.regions[id] as Region).population == 0, "an empty region stays empty")
	s.free()


func _test_stats() -> void:
	var s = _world()
	var total := 0
	for cid in s.countries:
		var from_country := PopulationStats.country_total(s.countries[cid], s.regions)
		var by_hand := 0
		for rid in (s.countries[cid] as Country).regions:
			by_hand += (s.regions[rid] as Region).population
		check(from_country == by_hand and from_country > 0, "country total is the sum of its regions")
		total += from_country
	check(total == PopulationStats.world_total(s.regions), "the countries add up to the world total")
	var rid: String = s.regions.keys()[3]
	var owner_id: String = (s.regions[rid] as Region).country_id
	var before := PopulationStats.country_total(s.countries[owner_id], s.regions)
	(s.regions[rid] as Region).population += 1000
	check(PopulationStats.country_total(s.countries[owner_id], s.regions) == before + 1000, "the total follows region changes")
	s.free()


func _test_through_the_tick_manager() -> void:
	var manager = ManagerScript.new()
	var s = _world()
	var events = EventBusScript.new()
	manager.state = s
	manager.event_bus = events
	manager.verbose = false
	GameSystems.register_all(manager)
	var start := PopulationStats.world_total(s.regions)
	for season in 8:
		manager.advance_season()
	var end := PopulationStats.world_total(s.regions)
	check(end > start, "advancing seasons through the manager grows the population")
	check(s.game_date.turn_number == 9, "the date advanced 8 seasons")
	manager.free()
	events.free()
	s.free()


func _test_survives_save_and_load() -> void:
	var a = _world()
	for season in 6:
		PopulationSystem.new().on_season_tick(a)
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict()))) == OK, "a world with grown populations loads")
	check(PopulationStats.world_total(a.regions) == PopulationStats.world_total(b.regions), "world population is identical after save and load")
	a.free()
	b.free()
