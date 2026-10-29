extends "res://tests/test_base.gd"


func _region(id: String, terrain: String, population: int) -> Region:
	var r := Region.from_static_dict({"id": id, "center": [1, 1], "terrain": terrain,
			"polygon": [[0, 0], [2, 0], [2, 2]], "neighbors": []})
	r.population = population
	return r


func _country(region_ids: Array) -> Country:
	return Country.from_start_dict({"id": "country_00001", "name": "T", "color": "#112233",
			"capital_region": region_ids[0], "regions": region_ids})


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001


func _init() -> void:
	print("test_economy_model")
	_test_config_sanity()
	_test_region_output()
	_test_fertility_by_terrain()
	_test_zero_and_scaling()
	_test_admin_cost()
	_test_country_report()
	_test_report_arithmetic()
	_test_deterministic()
	_test_next_treasury()
	_test_money_is_saved_exactly()
	_test_building_bonuses()
	_test_building_gain()
	_test_report_with_cities()
	finish()


func _test_config_sanity() -> void:
	check(EconomyConfig.FERTILITY.size() == Region.Terrain.size(), "one fertility value per terrain")
	check(EconomyConfig.GOLD_PER_PERSON > 0.0 and EconomyConfig.ADMIN_COST_PER_REGION > 0.0, "rates are positive")
	check(EconomyConfig.STARTING_TREASURY >= 0.0, "starting treasury is not negative")


func _test_region_output() -> void:
	var out := EconomyModel.region_output(_region("region_00001", "plains", 100000))
	check(_near(out[ResourceTypes.Type.GOLD], 50.0), "100000 people make 50 gold")
	check(_near(out[ResourceTypes.Type.FOOD], 130.0), "plains food = 100000 * 0.001 * 1.3 = 130")
	check(_near(out[ResourceTypes.Type.INDUSTRY], 20.0), "industry = 20")
	check(_near(out[ResourceTypes.Type.SCIENCE], 5.0), "science = 5")
	check(_near(out[ResourceTypes.Type.MANPOWER], 200.0), "manpower = 200")
	check(out.size() == ResourceTypes.Type.size(), "every resource type has a value")


func _test_fertility_by_terrain() -> void:
	var plains: float = EconomyModel.region_output(_region("region_00001", "plains", 100000))[ResourceTypes.Type.FOOD]
	var desert: float = EconomyModel.region_output(_region("region_00001", "desert", 100000))[ResourceTypes.Type.FOOD]
	var mountain: float = EconomyModel.region_output(_region("region_00001", "mountain", 100000))[ResourceTypes.Type.FOOD]
	check(plains > mountain and mountain > desert, "food: plains > mountain > desert")
	var gold_plains: float = EconomyModel.region_output(_region("region_00001", "plains", 100000))[ResourceTypes.Type.GOLD]
	var gold_desert: float = EconomyModel.region_output(_region("region_00001", "desert", 100000))[ResourceTypes.Type.GOLD]
	check(_near(gold_plains, gold_desert), "gold does not depend on terrain, only on people")


func _test_zero_and_scaling() -> void:
	var empty := EconomyModel.region_output(_region("region_00001", "plains", 0))
	var all_zero := true
	for type in empty:
		if empty[type] != 0.0:
			all_zero = false
	check(all_zero, "an empty region produces nothing")
	var one := EconomyModel.region_output(_region("region_00001", "hills", 70000))
	var two := EconomyModel.region_output(_region("region_00001", "hills", 140000))
	var linear := true
	for type in one:
		if not _near(two[type] , 2.0 * one[type]):
			linear = false
	check(linear, "double the people, double the output")
	var negative := EconomyModel.region_output(_region("region_00001", "plains", -5))
	check(negative[ResourceTypes.Type.GOLD] == 0.0, "a negative population is treated as 0")


func _test_admin_cost() -> void:
	var c := _country(["region_00001", "region_00002", "region_00003"])
	check(_near(EconomyModel.admin_cost(c), 150.0), "3 regions cost 3 * 50 gold")
	c.regions.clear()
	check(EconomyModel.admin_cost(c) == 0.0, "no regions, no administration cost")


func _test_country_report() -> void:
	var regions := {
		"region_00001": _region("region_00001", "plains", 100000),
		"region_00002": _region("region_00002", "desert", 40000),
		"region_00003": _region("region_00003", "hills", 900000),
	}
	var c := _country(["region_00001", "region_00002"])
	var report := EconomyModel.country_report(c, regions)
	check(_near(report.gold_income(), 70.0), "income = 50 + 20 (region_00003 belongs to nobody here)")
	check(_near(report.expenses(), 100.0), "expenses = 2 regions * 50")
	check(_near(report.net_gold(), -30.0), "a thin country can run a deficit")
	check(_near(report.get_output(ResourceTypes.Type.MANPOWER), 280.0), "manpower sums over regions")
	check(report.expense_items.has("Administration"), "administration is a named expense item")

	c.regions.append("region_00099")
	var with_ghost := EconomyModel.country_report(c, regions)
	check(_near(with_ghost.gold_income(), 70.0), "an unknown region id is ignored by the income")


func _test_report_arithmetic() -> void:
	var report := EconomyReport.new()
	report.output[ResourceTypes.Type.GOLD] = 300.0
	report.expense_items["A"] = 100.0
	report.expense_items["B"] = 50.0
	check(report.expenses() == 150.0, "expenses sum all items")
	check(report.net_gold() == 150.0, "net = income - expenses")
	check(report.get_output(ResourceTypes.Type.FOOD) == 0.0, "a missing output reads as 0")


func _test_deterministic() -> void:
	var regions := {
		"region_00001": _region("region_00001", "plains", 123457),
		"region_00002": _region("region_00002", "forest", 98765),
	}
	var c := _country(["region_00001", "region_00002"])
	var a := EconomyModel.country_report(c, regions)
	var b := EconomyModel.country_report(c, regions)
	check(a.output == b.output and a.expense_items == b.expense_items, "the same input always gives the identical report")


func _test_next_treasury() -> void:
	check(EconomyModel.next_treasury(100.0, 50.0) == 150.0, "positive net adds")
	check(EconomyModel.next_treasury(100.0, -30.0) == 70.0, "negative net subtracts")
	check(EconomyModel.next_treasury(10.0, -30.0) == 0.0, "the treasury never goes below 0")
	check(EconomyModel.next_treasury(0.0, -30.0) == 0.0, "an empty treasury stays at 0")
	check(EconomyModel.next_treasury(EconomyConfig.TREASURY_LIMIT, 1.0e9) == EconomyConfig.TREASURY_LIMIT, "the treasury is capped")
	check(EconomyModel.next_treasury(100.0, NAN) == 100.0, "a NaN net is ignored")
	check(EconomyModel.next_treasury(100.0, INF) == 100.0, "an infinite net is ignored")
	check(EconomyModel.next_treasury(100.0, -INF) == 100.0, "a negative infinite net is ignored")
	check(EconomyModel.next_treasury(NAN, 20.0) == 20.0, "a NaN treasury is reset to 0 first")
	check(EconomyModel.next_treasury(-50.0, 20.0) == 0.0, "an already negative treasury is lifted to 0")


func _test_money_is_saved_exactly() -> void:
	check(EconomyModel.round_money(0.1 + 0.2) == 0.3, "round_money cleans floating point noise")
	check(EconomyModel.round_money(2250.123456789) == 2250.12, "round_money rounds to cents")
	check(EconomyModel.round_money(1005.0) == 1005.0, "round_money keeps whole amounts")
	check(EconomyModel.next_treasury(500.0, 1750.123456789) == 2250.12, "next_treasury returns whole cents")
	# Godot's JSON keeps ~15 significant digits: cent-rounded money must survive it exactly.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var exact := 0
	var total := 3000
	for i in total:
		var money := EconomyModel.round_money(rng.randf_range(0.0, 5.0e10))
		var back: float = JSON.parse_string(JSON.stringify(money))
		if back == money:
			exact += 1
	check(exact == total, "3000 random amounts up to 5e10 survive JSON exactly (%d of %d)" % [exact, total])


func _test_building_bonuses() -> void:
	var r := _region("region_00001", "plains", 100000)
	var plain := EconomyModel.region_output(r)
	var boosted := EconomyModel.region_output(r, {ResourceTypes.Type.FOOD: 0.35})
	check(_near(boosted[ResourceTypes.Type.FOOD], 130.0 * 1.35), "+35% food: 130 -> 175.5")
	check(_near(boosted[ResourceTypes.Type.GOLD], plain[ResourceTypes.Type.GOLD]), "other resources are untouched")
	var halved := EconomyModel.region_output(r, {ResourceTypes.Type.GOLD: -0.5})
	check(_near(halved[ResourceTypes.Type.GOLD], 25.0), "a negative modifier reduces output")
	var floored := EconomyModel.region_output(r, {ResourceTypes.Type.GOLD: -3.0})
	check(floored[ResourceTypes.Type.GOLD] == 0.0, "output never goes below 0")
	check(EconomyModel.region_output(r, {}) == plain, "empty bonuses change nothing")


func _test_building_gain() -> void:
	var r := _region("region_00001", "plains", 100000)
	var farm := Building.from_dict({"id": "farm", "name": "Farm", "cost": 1, "build_seasons": 1, "output_modifiers": {"food": 0.35}})
	var market := Building.from_dict({"id": "market", "name": "Market", "cost": 1, "build_seasons": 1, "output_modifiers": {"gold": 0.25}})
	check(_near(EconomyModel.building_gain(r, farm)[ResourceTypes.Type.FOOD], 45.5), "a farm would add 45.5 food here")
	check(_near(EconomyModel.building_gain(r, market)[ResourceTypes.Type.GOLD], 12.5), "a market would add 12.5 gold here")
	check(EconomyModel.building_gain(r, farm).size() == 1, "only the resources the building affects")
	r.population = 0
	check(EconomyModel.building_gain(r, farm)[ResourceTypes.Type.FOOD] == 0.0, "an empty region gains nothing")


func _test_report_with_cities() -> void:
	var r1 := _region("region_00001", "plains", 100000)
	var r2 := _region("region_00002", "plains", 100000)
	var regions := {r1.id: r1, r2.id: r2}
	var city := City.from_dict({"id": "city_00001", "name": "A", "region_id": "region_00001", "level": "town", "buildings": ["farm"]})
	r1.cities.append(city.id)
	var cities := {city.id: city}
	BuildingCatalog.override_for_tests({"farm": Building.from_dict({"id": "farm", "name": "Farm", "cost": 1, "build_seasons": 1, "output_modifiers": {"food": 0.35}})})
	var both := _country(["region_00001", "region_00002"])
	var with_city := EconomyModel.country_report(both, regions, cities)
	var without := EconomyModel.country_report(both, regions)
	check(_near(with_city.get_output(ResourceTypes.Type.FOOD), 130.0 * 1.35 + 130.0), "the city's farm boosts only its own region")
	check(_near(without.get_output(ResourceTypes.Type.FOOD), 260.0), "without cities the output is the plain sum")
	var only_second := Country.from_start_dict({"id": "country_00002", "name": "B", "color": "#112233",
			"capital_region": "region_00002", "regions": ["region_00002"]})
	check(_near(EconomyModel.country_report(only_second, regions, cities).get_output(ResourceTypes.Type.FOOD), 130.0), "a city in another country's region does not count")
	BuildingCatalog.reset_cache()
