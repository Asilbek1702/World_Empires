extends "res://tests/test_base.gd"

const ManagerScript := preload("res://core/game_time/season_tick_manager.gd")
const StateScript := preload("res://world/world_state.gd")
const BusScript := preload("res://core/command_system/command_bus.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _init() -> void:
	print("test_production_system")
	BuildingCatalog.reset_cache()
	_test_phase_and_registration()
	_test_construction_takes_exactly_its_duration()
	_test_completion_event_fires_once()
	_test_farm_effect_applied_once()
	_test_market_raises_gold_income()
	_test_bonuses_stack_and_stay_local()
	_test_queue_is_sequential()
	_test_survives_save_and_load_mid_construction()
	_test_same_season_counts_in_the_economy()
	_test_idle_world_is_unchanged()
	BuildingCatalog.reset_cache()
	finish()


func _world() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _own_city(state: Node) -> City:
	var ids: Array = state.countries.keys()
	ids.sort()
	var country: Country = state.countries[ids[0]]
	for city_id in state.cities:
		var city: City = state.cities[city_id]
		if (state.regions[city.region_id] as Region).country_id == country.id and city.region_id != country.capital_region:
			return city
	return null


func _owner_of(state: Node, city: City) -> Country:
	return state.countries[(state.regions[city.region_id] as Region).country_id]


func _order(state: Node, city: City, building_id: String) -> void:
	var bus = BusScript.new()
	var events = EventBusScript.new()
	bus.state = state
	bus.event_bus = events
	bus.verbose = false
	var result: CommandResult = bus.submit(BuildBuildingCommand.new(city.id, building_id))
	check(result.ok, "order %s accepted" % building_id)
	bus.free()
	events.free()


func _report(state: Node, city: City) -> EconomyReport:
	return EconomyModel.country_report(_owner_of(state, city), state.regions, state.cities)


func _test_phase_and_registration() -> void:
	check(ProductionSystem.new().get_tick_phase() == TickOrder.Phase.PRODUCTION, "the system runs in the PRODUCTION phase")
	check(TickOrder.Phase.PRODUCTION < TickOrder.Phase.ECONOMY, "production runs before the economy")
	var manager = ManagerScript.new()
	GameSystems.register_all(manager)
	check(manager.get_systems_in_phase(TickOrder.Phase.PRODUCTION).size() == 1, "register_all registers the production system")
	manager.free()


func _test_construction_takes_exactly_its_duration() -> void:
	var s = _world()
	var city := _own_city(s)
	_order(s, city, "farm")
	var system := ProductionSystem.new()
	system.on_season_tick(s)
	system.on_season_tick(s)
	check(city.buildings.is_empty() and city.queue.size() == 1, "after 2 of 3 seasons the farm is not built")
	check(city.queue[0].seasons_done == 2, "the queue remembers the progress across ticks")
	system.on_season_tick(s)
	check(city.buildings == ["farm"] and city.queue.is_empty(), "after 3 seasons the farm is built and the queue is empty")
	s.free()


func _test_completion_event_fires_once() -> void:
	var s = _world()
	var city := _own_city(s)
	_order(s, city, "farm")
	var completed: Array = []
	var changed: Array = []
	s.building_completed.connect(func(c, b): completed.append([c, b]))
	s.city_changed.connect(func(c): changed.append(c))
	var system := ProductionSystem.new()
	for season in 8:
		system.on_season_tick(s)
	check(completed == [[city.id, "farm"]], "building_completed fires exactly once with (city, building)")
	check(changed == [city.id], "city_changed fires once, on completion")
	check(city.buildings == ["farm"], "the farm is in the city exactly once")
	s.free()


func _test_farm_effect_applied_once() -> void:
	var s = _world()
	var city := _own_city(s)
	var region: Region = s.regions[city.region_id]
	var before := _report(s, city)
	var farm_food := EconomyModel.region_output(region)[ResourceTypes.Type.FOOD] as float
	_order(s, city, "farm")
	var during := _report(s, city)
	check(_near(during.get_output(ResourceTypes.Type.FOOD), before.get_output(ResourceTypes.Type.FOOD)), "an unfinished farm changes nothing")
	var system := ProductionSystem.new()
	for season in 3:
		system.on_season_tick(s)
	var after := _report(s, city)
	check(_near(after.get_output(ResourceTypes.Type.FOOD) - before.get_output(ResourceTypes.Type.FOOD), farm_food * 0.35), "the finished farm adds exactly +35% of the region's food")
	for season in 5:
		system.on_season_tick(s)
	var much_later := _report(s, city)
	check(_near(much_later.get_output(ResourceTypes.Type.FOOD), after.get_output(ResourceTypes.Type.FOOD)), "the effect is not applied again in later seasons")
	check(_near(after.gold_income(), before.gold_income()), "a farm does not change gold")
	s.free()


func _test_market_raises_gold_income() -> void:
	var s = _world()
	var city := _own_city(s)
	var region: Region = s.regions[city.region_id]
	var before := _report(s, city)
	var market_gold := EconomyModel.region_output(region)[ResourceTypes.Type.GOLD] as float
	_order(s, city, "market")
	var system := ProductionSystem.new()
	for season in 4:
		system.on_season_tick(s)
	var after := _report(s, city)
	check(_near(after.gold_income() - before.gold_income(), market_gold * 0.25), "the market adds +25%% of the region's gold (%.2f)" % (market_gold * 0.25))
	check(_near(after.net_gold() - before.net_gold(), market_gold * 0.25), "and it all lands in the net income")
	s.free()


func _test_bonuses_stack_and_stay_local() -> void:
	var override := {
		"farm": Building.from_dict({"id": "farm", "name": "Farm", "cost": 1, "build_seasons": 1, "output_modifiers": {"food": 0.35}}),
		"granary": Building.from_dict({"id": "granary", "name": "Granary", "cost": 1, "build_seasons": 1, "output_modifiers": {"food": 0.2}}),
	}
	BuildingCatalog.override_for_tests(override)
	var s = _world()
	var city := _own_city(s)
	var region: Region = s.regions[city.region_id]
	var base_food := EconomyModel.region_output(region)[ResourceTypes.Type.FOOD] as float
	var other_country: Country = null
	for id in s.countries:
		if id != _owner_of(s, city).id:
			other_country = s.countries[id]
			break
	var other_before := EconomyModel.country_report(other_country, s.regions, s.cities)
	var own_before := _report(s, city)
	city.buildings.append("farm")
	city.buildings.append("granary")
	var own_after := _report(s, city)
	check(_near(own_after.get_output(ResourceTypes.Type.FOOD) - own_before.get_output(ResourceTypes.Type.FOOD), base_food * 0.55), "two food buildings add up: +35%% and +20%% = +55%% of the base")
	var other_after := EconomyModel.country_report(other_country, s.regions, s.cities)
	check(other_after.output == other_before.output, "buildings of one country do not change another country")
	var bonuses := ProductionModel.region_bonuses(region, s.cities)
	check(_near(bonuses[ResourceTypes.Type.FOOD], 0.55), "region_bonuses sums the modifiers")
	s.free()
	BuildingCatalog.reset_cache()


func _test_queue_is_sequential() -> void:
	var s = _world()
	var city := _own_city(s)
	_order(s, city, "farm")
	_order(s, city, "market")
	var system := ProductionSystem.new()
	for season in 3:
		system.on_season_tick(s)
	check(city.buildings == ["farm"], "the farm (3 seasons) is done after 3 seasons")
	check(city.queue.size() == 1 and city.queue[0].seasons_done == 0, "the market has not started before the farm is done")
	for season in 4:
		system.on_season_tick(s)
	check(city.buildings == ["farm", "market"], "the market (4 seasons) is done 4 seasons later")
	s.free()


func _test_survives_save_and_load_mid_construction() -> void:
	var a = _world()
	var city := _own_city(a)
	_order(a, city, "factory")
	var system := ProductionSystem.new()
	for season in 4:
		system.on_season_tick(a)
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict()))) == OK, "a world with a half-built factory loads")
	var loaded: City = b.cities[city.id]
	check(loaded.queue.size() == 1 and loaded.queue[0].seasons_done == 4 and loaded.queue[0].seasons_total == 6, "progress 4 of 6 survives the file")
	for season in 2:
		system.on_season_tick(a)
		system.on_season_tick(b)
	check(city.buildings == ["factory"] and loaded.buildings == ["factory"], "both worlds finish the factory in the same season")
	check(a.to_dict() == b.to_dict(), "the loaded world stays identical to the original")
	check(WorldIntegrity.check(b).is_empty(), "the loaded world is consistent")
	a.free()
	b.free()


func _test_same_season_counts_in_the_economy() -> void:
	var override := {"bank": Building.from_dict({"id": "bank", "name": "Bank", "cost": 10, "build_seasons": 1, "output_modifiers": {"gold": 0.5}})}
	BuildingCatalog.override_for_tests(override)
	var with_bank = _world()
	var without_bank = _world()
	var city := _own_city(with_bank)
	_order(with_bank, city, "bank")
	var owner_id := _owner_of(with_bank, city).id

	var manager = ManagerScript.new()
	manager.state = with_bank
	manager.event_bus = EventBusScript.new()
	manager.verbose = false
	GameSystems.register_all(manager)
	manager.advance_season()
	var plain = ManagerScript.new()
	plain.state = without_bank
	plain.event_bus = EventBusScript.new()
	plain.verbose = false
	GameSystems.register_all(plain)
	plain.advance_season()

	# population grows before the economy runs, so the bonus is 50% of the GROWN region's gold
	var gold_here := EconomyModel.region_output(without_bank.regions[city.region_id])[ResourceTypes.Type.GOLD] as float
	var gained: float = (with_bank.countries[owner_id] as Country).treasury - (without_bank.countries[owner_id] as Country).treasury
	# the bank costs 10 once and pays +50% of this region's gold in the very season it is finished
	var expected := gold_here * 0.5 - 10.0
	# both treasuries are rounded to cents, so the difference is exact only to a cent
	check(absf(gained - expected) <= 0.011, "a building finished this season already pays this season (gained %.2f, expected %.2f)" % [gained, expected])
	manager.event_bus.free()
	plain.event_bus.free()
	manager.free()
	plain.free()
	with_bank.free()
	without_bank.free()
	BuildingCatalog.reset_cache()


func _test_idle_world_is_unchanged() -> void:
	var s = _world()
	var before: Dictionary = s.to_dict()["cities"]
	var system := ProductionSystem.new()
	for season in 10:
		system.on_season_tick(s)
	check(s.to_dict()["cities"] == before, "cities without orders do not change")
	s.free()
