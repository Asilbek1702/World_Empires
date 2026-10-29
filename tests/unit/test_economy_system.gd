extends "res://tests/test_base.gd"

const ManagerScript := preload("res://core/game_time/season_tick_manager.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _init() -> void:
	print("test_economy_system")
	_test_phase_and_registration()
	_test_mock_country_delta()
	_test_countries_are_independent()
	_test_treasury_floor()
	_test_region_transfer_changes_income()
	_test_everyone_starts_in_profit()
	_test_order_after_population()
	_test_long_run_is_finite_and_deterministic()
	_test_survives_save_and_load()
	finish()


## Country A owns r1 (plains 100k) and r2 (desert 40k). Country B owns r3 (hills 200k).
func _mini_world() -> Node:
	var specs := [["region_00001", "plains", 100000], ["region_00002", "desert", 40000],
			["region_00003", "hills", 200000]]
	var regions := {}
	for spec in specs:
		var r := Region.from_static_dict({"id": spec[0], "center": [1, 1], "terrain": spec[1],
				"polygon": [[0, 0], [2, 0], [2, 2]], "neighbors": []})
		r.population = spec[2]
		regions[r.id] = r
	var a := Country.from_start_dict({"id": "country_00001", "name": "A", "color": "#aa0000",
			"capital_region": "region_00001", "regions": ["region_00001", "region_00002"]})
	var b := Country.from_start_dict({"id": "country_00002", "name": "B", "color": "#0000aa",
			"capital_region": "region_00003", "regions": ["region_00003"]})
	for country in [a, b]:
		country.treasury = 500.0
		for rid in country.regions:
			(regions[rid] as Region).country_id = country.id
	var s = StateScript.new()
	s.new_game(1, null, regions, {a.id: a, b.id: b})
	return s


func _test_phase_and_registration() -> void:
	check(EconomySystem.new().get_tick_phase() == TickOrder.Phase.ECONOMY, "the system runs in the ECONOMY phase")
	var manager = ManagerScript.new()
	GameSystems.register_all(manager)
	check(manager.get_systems_in_phase(TickOrder.Phase.ECONOMY).size() == 1, "register_all registers the economy system")
	check(manager.get_systems_in_phase(TickOrder.Phase.POPULATION).size() == 1, "and still the population system")
	manager.free()


func _test_mock_country_delta() -> void:
	var s = _mini_world()
	EconomySystem.new().on_season_tick(s)
	# A: income 50 + 20 = 70, expenses 2 * 50 = 100, net -30
	check(_near((s.countries["country_00001"] as Country).treasury, 470.0), "A: 500 + 70 - 100 = 470")
	# B: income 100, expenses 50, net +50
	check(_near((s.countries["country_00002"] as Country).treasury, 550.0), "B: 500 + 100 - 50 = 550")
	EconomySystem.new().on_season_tick(s)
	check(_near((s.countries["country_00001"] as Country).treasury, 440.0), "a second season: 470 - 30 = 440")
	s.free()


func _test_countries_are_independent() -> void:
	var s = _mini_world()
	(s.regions["region_00001"] as Region).population = 1000000
	EconomySystem.new().on_season_tick(s)
	check(_near((s.countries["country_00002"] as Country).treasury, 550.0), "changing A's people does not change B's treasury")
	check(_near((s.countries["country_00001"] as Country).treasury, 500.0 + 500.0 + 20.0 - 100.0), "A earns from its larger region")
	s.free()


func _test_treasury_floor() -> void:
	var s = _mini_world()
	(s.countries["country_00001"] as Country).treasury = 10.0
	for season in 5:
		EconomySystem.new().on_season_tick(s)
	check((s.countries["country_00001"] as Country).treasury == 0.0, "a deficit stops at 0, never negative")
	s.free()


func _test_region_transfer_changes_income() -> void:
	var s = WorldState_real()
	var ids: Array = s.countries.keys()
	ids.sort()
	var giver: Country = s.countries[ids[0]]
	var taker: Country = s.countries[ids[1]]
	var rid := ""
	for candidate in giver.regions:
		if candidate != giver.capital_region:
			rid = candidate
			break
	var gold := EconomyModel.region_output(s.regions[rid])[ResourceTypes.Type.GOLD] as float
	var giver_before := EconomyModel.country_report(giver, s.regions).net_gold()
	var taker_before := EconomyModel.country_report(taker, s.regions).net_gold()
	s.set_region_owner(rid, taker.id)
	var giver_after := EconomyModel.country_report(giver, s.regions).net_gold()
	var taker_after := EconomyModel.country_report(taker, s.regions).net_gold()
	var admin := EconomyConfig.ADMIN_COST_PER_REGION
	check(_near(giver_after, giver_before - gold + admin), "the giver loses the region's gold and saves its administration cost")
	check(_near(taker_after, taker_before + gold - admin), "the taker gains the region's gold and pays its administration cost")
	s.free()


func WorldState_real() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _test_everyone_starts_in_profit() -> void:
	var s = WorldState_real()
	var all_positive := true
	var lowest := 1.0e18
	for id in s.countries:
		var net := EconomyModel.country_report(s.countries[id], s.regions).net_gold()
		lowest = minf(lowest, net)
		if net <= 0.0:
			all_positive = false
	check(all_positive, "every country starts with a positive net income (lowest %.0f)" % lowest)
	for id in s.countries:
		check((s.countries[id] as Country).treasury == EconomyConfig.STARTING_TREASURY, "%s starts with the configured treasury" % id)
		break
	s.free()


func _test_order_after_population() -> void:
	# world 1: both systems through the manager. world 2: population first, then the economy by hand.
	var manager = ManagerScript.new()
	var a = WorldState_real()
	var events = EventBusScript.new()
	manager.state = a
	manager.event_bus = events
	manager.verbose = false
	GameSystems.register_all(manager)
	manager.advance_season()

	var b = WorldState_real()
	PopulationSystem.new().on_season_tick(b)
	var cid: String = b.countries.keys()[0]
	var expected := EconomyModel.next_treasury(EconomyConfig.STARTING_TREASURY,
			EconomyModel.country_report(b.countries[cid], b.regions).net_gold())
	check(_near((a.countries[cid] as Country).treasury, expected), "income uses the population AFTER this season's growth")

	var c = WorldState_real()
	var stale := EconomyModel.next_treasury(EconomyConfig.STARTING_TREASURY,
			EconomyModel.country_report(c.countries[cid], c.regions).net_gold())
	check(expected > stale, "growth makes the income slightly higher than the forecast")
	manager.free()
	events.free()
	a.free()
	b.free()
	c.free()


func _run_seasons(s: Node, count: int) -> void:
	var pop := PopulationSystem.new()
	var eco := EconomySystem.new()
	for season in count:
		pop.on_season_tick(s)
		eco.on_season_tick(s)


func _test_long_run_is_finite_and_deterministic() -> void:
	var a = WorldState_real()
	var b = WorldState_real()
	_run_seasons(a, 120)
	_run_seasons(b, 120)
	var finite := true
	var grew := true
	for id in a.countries:
		var t: float = (a.countries[id] as Country).treasury
		if not is_finite(t) or t < 0.0:
			finite = false
		if t <= EconomyConfig.STARTING_TREASURY:
			grew = false
	check(finite, "after 120 seasons every treasury is finite and not negative")
	check(grew, "after 120 seasons every treasury has grown")
	check(a.to_dict() == b.to_dict(), "two worlds give identical treasuries after 120 seasons")
	a.free()
	b.free()


func _test_survives_save_and_load() -> void:
	var a = WorldState_real()
	_run_seasons(a, 12)
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict()))) == OK, "a world with a grown treasury loads")
	var same := true
	for id in a.countries:
		if (a.countries[id] as Country).treasury != (b.countries[id] as Country).treasury:
			same = false
	check(same, "every treasury is exactly the same after save and load")
	a.free()
	b.free()
