extends "res://tests/test_base.gd"

const StateScript := preload("res://world/world_state.gd")


func _init() -> void:
	print("test_world_state")
	_test_defaults()
	_test_new_game()
	_test_new_game_clears_entities()
	_test_dict_roundtrip()
	_test_large_values_survive_json()
	_test_from_dict_rejects_bad_data()
	_test_failed_from_dict_changes_nothing()
	_test_state_replaced_signal()
	_test_regions_roundtrip()
	_test_regions_json_roundtrip()
	_test_regions_bad_data_rejected()
	_test_cities_roundtrip()
	_test_cities_bad_data_rejected()
	finish()


func _test_defaults() -> void:
	var s = StateScript.new()
	check(str(s.game_date) == "Spring 1000", "default date is Spring 1000")
	check(s.rng_seed == 0, "default seed is 0")
	check(s.countries.is_empty() and s.regions.is_empty(), "countries and regions start empty")
	check(s.cities.is_empty() and s.armies.is_empty(), "cities and armies start empty")
	s.free()


func _test_new_game() -> void:
	var s = StateScript.new()
	s.new_game(12345)
	check(s.rng_seed == 12345, "new_game sets the seed")
	check(str(s.game_date) == "Spring 1000", "new_game default start date")
	s.new_game(1, GameDate.new(1914, GameDate.Season.SUMMER, 10))
	check(str(s.game_date) == "Summer 1914", "new_game accepts a start date")
	s.free()


func _test_new_game_clears_entities() -> void:
	var s = StateScript.new()
	s.countries["country_00001"] = {"name": "X"}
	s.armies["army_00001"] = {}
	s.new_game(1)
	check(s.countries.is_empty() and s.armies.is_empty(), "new_game clears entity dictionaries")
	s.free()


func _test_dict_roundtrip() -> void:
	var a = StateScript.new()
	a.new_game(777)
	a.game_date.advance()
	a.game_date.advance()
	a.rng_state = 99
	var b = StateScript.new()
	var error: Error = b.from_dict(a.to_dict())
	check(error == OK, "from_dict accepts to_dict output")
	check(a.to_dict() == b.to_dict(), "round trip keeps every field")
	check(str(b.game_date) == "Autumn 1000" and b.rng_seed == 777, "date and seed restored")
	a.free()
	b.free()


func _test_large_values_survive_json() -> void:
	var a = StateScript.new()
	a.new_game(9007199254740993)  # 2^53 + 1, not representable as a JSON float
	a.rng_state = -9223372036854775807
	var parsed: Variant = JSON.parse_string(JSON.stringify(a.to_dict()))
	var b = StateScript.new()
	check(b.from_dict(parsed) == OK, "from_dict accepts parsed JSON")
	check(b.rng_seed == 9007199254740993, "seed above 2^53 survives JSON exactly")
	check(b.rng_state == -9223372036854775807, "negative 64-bit state survives JSON exactly")
	a.free()
	b.free()


func _good_dict() -> Dictionary:
	var s = StateScript.new()
	s.new_game(5)
	var d: Dictionary = s.to_dict()
	s.free()
	return d


func _test_from_dict_rejects_bad_data() -> void:
	var s = StateScript.new()
	check(s.from_dict(_good_dict()) == OK, "baseline dict is accepted")

	var d := _good_dict()
	d.erase("game_date")
	check(s.from_dict(d) == ERR_INVALID_DATA, "missing game_date rejected")

	d = _good_dict()
	d["game_date"]["season"] = 9
	check(s.from_dict(d) == ERR_INVALID_DATA, "bad season rejected")

	d = _good_dict()
	d["rng_seed"] = 12345
	check(s.from_dict(d) == ERR_INVALID_DATA, "numeric rng_seed rejected (must be text)")

	d = _good_dict()
	d["rng_seed"] = "abc"
	check(s.from_dict(d) == ERR_INVALID_DATA, "non-numeric rng_seed rejected")

	d = _good_dict()
	d.erase("rng_state")
	check(s.from_dict(d) == ERR_INVALID_DATA, "missing rng_state rejected")

	d = _good_dict()
	d["regions"] = []
	check(s.from_dict(d) == ERR_INVALID_DATA, "regions that are not a dictionary rejected")
	s.free()


func _test_failed_from_dict_changes_nothing() -> void:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 42, GameDate.new(1800, GameDate.Season.WINTER, 9))
	var before: Dictionary = s.to_dict()
	var bad := _good_dict()
	bad["armies"] = "broken"
	s.from_dict(bad)
	check(s.to_dict() == before, "failed from_dict leaves the state untouched")
	s.free()


func _test_state_replaced_signal() -> void:
	var s = StateScript.new()
	var count := [0]
	s.state_replaced.connect(func(): count[0] += 1)
	s.new_game(1)
	check(count[0] == 1, "new_game emits state_replaced")
	s.from_dict(_good_dict())
	check(count[0] == 2, "successful from_dict emits state_replaced")
	var bad := _good_dict()
	bad.erase("game_date")
	s.from_dict(bad)
	check(count[0] == 2, "failed from_dict does not emit state_replaced")
	s.free()


func _world_with_map() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _movable_region(state: Node, from_country: String) -> String:
	for rid in (state.countries[from_country] as Country).regions:
		if rid != (state.countries[from_country] as Country).capital_region:
			return rid
	return ""


func _test_regions_roundtrip() -> void:
	var a = _world_with_map()
	var ids: Array = a.regions.keys()
	var countries: Array = a.countries.keys()
	countries.sort()
	var moved := _movable_region(a, countries[0])
	a.set_region_owner(moved, countries[1])
	(a.regions[ids[0]] as Region).population = 4200
	(a.regions[ids[5]] as Region).resources = {"iron": 7}
	a.set_player_country(countries[2])
	var b = StateScript.new()
	check(b.from_dict(a.to_dict()) == OK, "from_dict accepts a world with regions and countries")
	check(b.regions.size() == a.regions.size() and b.countries.size() == a.countries.size(), "all regions and countries restored")
	check((b.regions[moved] as Region).country_id == countries[1], "region owner restored")
	check((b.countries[countries[1]] as Country).regions.has(moved), "country region list rebuilt from owners")
	check(not (b.countries[countries[0]] as Country).regions.has(moved), "old owner list rebuilt without the region")
	check((b.regions[ids[0]] as Region).population == 4200, "region population restored")
	check(int((b.regions[ids[5]] as Region).resources["iron"]) == 7, "region resources restored")
	check((b.regions[ids[0]] as Region).polygon.size() >= 3, "static geometry is back after load")
	check(b.get_player_country() != null and b.get_player_country().id == countries[2], "player country restored")
	check(WorldIntegrity.check(b).is_empty(), "loaded world is consistent")
	check(a.to_dict() == b.to_dict(), "saved state identical after round trip")
	check(a.regions[ids[0]] != b.regions[ids[0]] and a.countries[countries[0]] != b.countries[countries[0]], "loaded objects are new instances")
	a.free()
	b.free()


func _test_regions_json_roundtrip() -> void:
	var a = _world_with_map()
	var text := JSON.stringify(a.to_dict())
	check(not ("polygon" in text), "saved data contains no polygons (static data is not saved)")
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(text)) == OK, "regions survive JSON")
	check(a.to_dict() == b.to_dict(), "state identical after JSON round trip")
	a.free()
	b.free()


func _test_regions_bad_data_rejected() -> void:
	var a = _world_with_map()
	var good: Dictionary = a.to_dict()
	var target = _world_with_map()
	target.game_date.advance()
	var before: Dictionary = target.to_dict()

	var unknown := good.duplicate(true)
	unknown["regions"]["region_99999"] = {"country_id": "", "population": 0, "resources": {}}
	check(target.from_dict(unknown) == ERR_INVALID_DATA, "unknown region id rejected")

	var bad_pop := good.duplicate(true)
	var first_id: String = bad_pop["regions"].keys()[0]
	bad_pop["regions"][first_id]["population"] = -5
	check(target.from_dict(bad_pop) == ERR_INVALID_DATA, "invalid region data rejected")
	check(target.to_dict() == before, "state untouched after rejected region data")

	var ghost_owner := good.duplicate(true)
	ghost_owner["regions"][first_id]["country_id"] = "country_99999"
	check(target.from_dict(ghost_owner) == ERR_INVALID_DATA, "region owned by an unknown country rejected")

	var ids: Array = good["countries"].keys()
	ids.sort()
	var bad_capital := good.duplicate(true)
	bad_capital["countries"][ids[0]]["capital_region"] = good["countries"][ids[1]]["capital_region"]
	check(target.from_dict(bad_capital) == ERR_INVALID_DATA, "capital inside another country rejected")

	var two_players := good.duplicate(true)
	two_players["countries"][ids[0]]["is_player_controlled"] = true
	two_players["countries"][ids[1]]["is_player_controlled"] = true
	check(target.from_dict(two_players) == ERR_INVALID_DATA, "two player countries rejected")

	var bad_country := good.duplicate(true)
	bad_country["countries"][ids[0]]["color"] = "blue-ish"
	check(target.from_dict(bad_country) == ERR_INVALID_DATA, "malformed country rejected")
	check(target.to_dict() == before, "state still untouched after every rejection")
	a.free()
	target.free()


func _first_city(state: Node) -> City:
	var ids: Array = state.cities.keys()
	ids.sort()
	return state.cities[ids[0]]


func _test_cities_roundtrip() -> void:
	var a = _world_with_map()
	check(a.cities.size() >= 40, "a built world has cities (%d)" % a.cities.size())
	var city := _first_city(a)
	city.buildings.append("farm")
	var order := ConstructionOrder.new()
	order.building_id = "market"
	order.seasons_total = 4
	order.seasons_done = 2
	city.queue.append(order)
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict()))) == OK, "a world with cities loads through JSON")
	check(b.cities.size() == a.cities.size(), "all cities restored")
	var loaded: City = b.cities[city.id]
	check(loaded.name == city.name and loaded.region_id == city.region_id and loaded.level == city.level, "city fields restored")
	check(loaded.buildings == ["farm"] and loaded.queue.size() == 1 and loaded.queue[0].seasons_done == 2, "buildings and queue progress restored")
	check((b.regions[city.region_id] as Region).cities == [city.id], "Region.cities is rebuilt from the cities")
	check(WorldIntegrity.check(b).is_empty(), "the loaded world is consistent")
	check(a.to_dict() == b.to_dict(), "saved state identical after the round trip")
	check(loaded != city, "loaded cities are new objects")
	a.free()
	b.free()


func _test_cities_bad_data_rejected() -> void:
	var a = _world_with_map()
	var good: Dictionary = a.to_dict()
	var target = _world_with_map()
	target.game_date.advance()
	var before: Dictionary = target.to_dict()
	var cid: String = good["cities"].keys()[0]

	var unknown_region := good.duplicate(true)
	unknown_region["cities"][cid]["region_id"] = "region_99999"
	check(target.from_dict(unknown_region) == ERR_INVALID_DATA, "a city in an unknown region rejected")

	var unknown_building := good.duplicate(true)
	unknown_building["cities"][cid]["buildings"] = ["castle"]
	check(target.from_dict(unknown_building) == ERR_INVALID_DATA, "an unknown building rejected")

	var bad_level := good.duplicate(true)
	bad_level["cities"][cid]["level"] = "megacity"
	check(target.from_dict(bad_level) == ERR_INVALID_DATA, "an unknown city level rejected")

	var twice := good.duplicate(true)
	twice["cities"][cid]["buildings"] = ["farm", "farm"]
	check(target.from_dict(twice) == ERR_INVALID_DATA, "a building twice rejected")

	var broken_order := good.duplicate(true)
	broken_order["cities"][cid]["queue"] = [{"building_id": "farm", "seasons_total": 3, "seasons_done": 7}]
	check(target.from_dict(broken_order) == ERR_INVALID_DATA, "a finished order in the queue rejected")

	var wrong_key := good.duplicate(true)
	wrong_key["cities"]["city_99999"] = wrong_key["cities"][cid]
	check(target.from_dict(wrong_key) == ERR_INVALID_DATA, "a city stored under another id rejected")

	check(target.to_dict() == before, "state untouched after every rejection")
	a.free()
	target.free()
