extends "res://tests/test_base.gd"

const StateScript := preload("res://world/world_state.gd")


func _world() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _first_region_of(state: Node, country_id: String) -> String:
	for rid in (state.countries[country_id] as Country).regions:
		if rid != (state.countries[country_id] as Country).capital_region:
			return rid
	return ""


func _init() -> void:
	print("test_world_integrity")
	_test_fresh_world_is_consistent()
	_test_unknown_owner()
	_test_unowned_regions()
	_test_index_out_of_sync()
	_test_capital_not_owned()
	_test_country_without_regions()
	_test_two_players()
	_test_city_rules()
	finish()


func _test_fresh_world_is_consistent() -> void:
	var s = _world()
	var problems: Array[String] = WorldIntegrity.check(s)
	check(problems.is_empty(), "a freshly built world is consistent %s" % str(problems.slice(0, 3)))
	check(WorldIntegrity.check_territory({}, {}, false).is_empty(), "an empty world is consistent")
	s.free()


func _test_unknown_owner() -> void:
	var s = _world()
	var rid: String = s.regions.keys()[0]
	(s.regions[rid] as Region).country_id = "country_99999"
	check(not WorldIntegrity.check(s).is_empty(), "region owned by an unknown country is caught")
	s.free()


func _test_unowned_regions() -> void:
	var s = _world()
	var cid: String = s.countries.keys()[0]
	var rid := _first_region_of(s, cid)
	(s.countries[cid] as Country).regions.erase(rid)
	(s.regions[rid] as Region).country_id = ""
	check(not WorldIntegrity.check(s, false).is_empty(), "unowned region is caught when not allowed")
	check(WorldIntegrity.check(s, true).is_empty(), "unowned region is accepted when allowed")
	s.free()


func _test_index_out_of_sync() -> void:
	var s = _world()
	var cid: String = s.countries.keys()[0]
	var country: Country = s.countries[cid]
	var removed: String = country.regions.pop_back()
	check(not WorldIntegrity.check(s).is_empty(), "missing entry in Country.regions is caught")
	country.regions.append(removed)
	check(WorldIntegrity.check(s).is_empty(), "restored index is consistent again")
	country.regions.append(removed)
	check(not WorldIntegrity.check(s).is_empty(), "duplicate entry in Country.regions is caught")
	s.free()


func _test_capital_not_owned() -> void:
	var s = _world()
	var ids: Array = s.countries.keys()
	var a: Country = s.countries[ids[0]]
	var b: Country = s.countries[ids[1]]
	a.capital_region = b.capital_region
	check(not WorldIntegrity.check(s).is_empty(), "capital inside another country is caught")
	a.capital_region = ""
	check(not WorldIntegrity.check(s).is_empty(), "missing capital is caught")
	s.free()


func _test_country_without_regions() -> void:
	var s = _world()
	var ghost := Country.new()
	ghost.id = "country_00099"
	ghost.name = "Ghost"
	s.countries[ghost.id] = ghost
	check(not WorldIntegrity.check(s).is_empty(), "country without regions is caught")
	s.free()


func _test_two_players() -> void:
	var s = _world()
	var ids: Array = s.countries.keys()
	(s.countries[ids[0]] as Country).is_player_controlled = true
	check(WorldIntegrity.check(s).is_empty(), "one player country is fine")
	(s.countries[ids[1]] as Country).is_player_controlled = true
	check(not WorldIntegrity.check(s).is_empty(), "two player countries are caught")
	s.free()


func _test_city_rules() -> void:
	var s = _world()
	check(WorldIntegrity.check_cities(s.cities, s.regions, BuildingCatalog.get_all()).is_empty(), "a fresh world has consistent cities")
	var city: City = s.cities.values()[0]

	var region: Region = s.regions[city.region_id]
	region.cities.clear()
	check(not WorldIntegrity.check(s).is_empty(), "a city missing from Region.cities is caught")
	region.cities.append(city.id)
	check(WorldIntegrity.check(s).is_empty(), "restored index is consistent again")

	var other_region: Region = null
	for rid in s.regions:
		if (s.regions[rid] as Region).cities.is_empty():
			other_region = s.regions[rid]
			break
	other_region.cities.append("city_99999")
	check(not WorldIntegrity.check(s).is_empty(), "a Region.cities entry without a city is caught")
	other_region.cities.clear()

	var old_region := city.region_id
	city.region_id = "region_99999"
	check(not WorldIntegrity.check(s).is_empty(), "a city in an unknown region is caught")
	city.region_id = old_region

	city.buildings.append("farm")
	city.buildings.append("farm")
	check(not WorldIntegrity.check(s).is_empty(), "a building twice in one city is caught")
	city.buildings.clear()

	city.buildings.append("castle")
	check(not WorldIntegrity.check(s).is_empty(), "an unknown building is caught")
	city.buildings.clear()

	var order := ConstructionOrder.new()
	order.building_id = "farm"
	order.seasons_total = 3
	city.buildings.append("farm")
	city.queue.append(order)
	check(not WorldIntegrity.check(s).is_empty(), "queueing a building that is already built is caught")
	city.buildings.clear()
	city.queue.clear()

	for id in ["farm", "market", "factory", "farm2"]:
		var extra := ConstructionOrder.new()
		extra.building_id = id
		extra.seasons_total = 2
		city.queue.append(extra)
	check(not WorldIntegrity.check(s).is_empty(), "a queue longer than the maximum is caught")
	city.queue.clear()
	check(WorldIntegrity.check(s).is_empty(), "back to consistent")
	s.free()
