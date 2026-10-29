extends "res://tests/test_base.gd"
## Tests the SHIPPED city file (data/cities/cities.json) against the shipped map and countries.


func _init() -> void:
	print("test_city_data")
	var regions := MapLoader.load_regions()
	var countries := CountryLoader.load_countries()
	var cities := CityLoader.load_cities()
	check(not cities.is_empty(), "cities load (%s)" % CityLoader.last_error)
	if cities.is_empty():
		finish()
		return
	_test_count_and_names(cities)
	_test_consistent(cities, regions, countries)
	_test_capitals(cities, countries)
	_test_spread(cities, regions)
	_test_per_country(cities, regions, countries)
	_test_validator_catches_problems()
	_test_loads_are_independent()
	_test_missing_file()
	finish()


func _test_count_and_names(cities: Dictionary) -> void:
	check(cities.size() >= 40 and cities.size() <= 120, "40..120 cities (is %d)" % cities.size())
	var names := {}
	var ok := true
	for id in cities:
		var city: City = cities[id]
		if names.has(city.name):
			ok = false
		names[city.name] = true
	check(ok, "city names are unique")


func _test_consistent(cities: Dictionary, regions: Dictionary, countries: Dictionary) -> void:
	var problems := CityLoader.validate_against_map(cities, regions, countries)
	check(problems.is_empty(), "cities are consistent with the map %s" % str(problems.slice(0, 3)))
	var fresh := true
	for id in cities:
		var city: City = cities[id]
		if not city.buildings.is_empty() or not city.queue.is_empty():
			fresh = false
	check(fresh, "cities start without buildings and without orders")


func _test_capitals(cities: Dictionary, countries: Dictionary) -> void:
	var by_region := {}
	for id in cities:
		by_region[(cities[id] as City).region_id] = cities[id]
	var ok := true
	for cid in countries:
		var capital: String = (countries[cid] as Country).capital_region
		if not by_region.has(capital) or (by_region[capital] as City).level != City.Level.CITY:
			ok = false
	check(ok, "every capital region has a city of level 'city'")


func _test_spread(cities: Dictionary, regions: Dictionary) -> void:
	var in_region := {}
	for id in cities:
		in_region[(cities[id] as City).region_id] = true
	var touching := 0
	for rid in in_region:
		for n in (regions[rid] as Region).neighbors:
			if in_region.has(n):
				touching += 1
	check(touching == 0, "no two cities are in neighboring regions (%d touching pairs)" % touching)


func _test_per_country(cities: Dictionary, regions: Dictionary, countries: Dictionary) -> void:
	var count := {}
	var owner_of := {}
	for cid in countries:
		for rid in (countries[cid] as Country).regions:
			owner_of[rid] = cid
	for id in cities:
		var cid: String = owner_of[(cities[id] as City).region_id]
		count[cid] = count.get(cid, 0) + 1
	var fewest := 999
	for cid in countries:
		fewest = mini(fewest, count.get(cid, 0))
	check(fewest >= 3, "every country has at least 3 cities (fewest: %d)" % fewest)


func _city(id: String, region: String) -> City:
	return City.from_dict({"id": id, "name": "N" + id, "region_id": region, "level": "town"})


func _test_validator_catches_problems() -> void:
	var regions := {}
	for rid in ["region_00001", "region_00002"]:
		regions[rid] = Region.from_static_dict({"id": rid, "center": [1, 1], "terrain": "plains",
				"polygon": [[0, 0], [2, 0], [2, 2]], "neighbors": []})
	var country := Country.from_start_dict({"id": "country_00001", "name": "A", "color": "#112233",
			"capital_region": "region_00001", "regions": ["region_00001", "region_00002"]})
	var countries := {country.id: country}
	var good := {"city_00001": _city("city_00001", "region_00001")}
	check(CityLoader.validate_against_map(good, regions, countries).is_empty(), "baseline mini world is valid")
	var unknown := {"city_00001": _city("city_00001", "region_00001"), "city_00002": _city("city_00002", "region_00077")}
	check(not CityLoader.validate_against_map(unknown, regions, countries).is_empty(), "a city in an unknown region is caught")
	var twice := {"city_00001": _city("city_00001", "region_00001"), "city_00002": _city("city_00002", "region_00001")}
	check(not CityLoader.validate_against_map(twice, regions, countries).is_empty(), "two cities in one region are caught")
	var no_capital := {"city_00001": _city("city_00001", "region_00002")}
	check(not CityLoader.validate_against_map(no_capital, regions, countries).is_empty(), "a capital region without a city is caught")


func _test_loads_are_independent() -> void:
	var one := CityLoader.load_cities()
	var two := CityLoader.load_cities()
	var id: String = one.keys()[0]
	(one[id] as City).buildings.append("farm")
	check((two[id] as City).buildings.is_empty(), "two loads never share City objects")


func _test_missing_file() -> void:
	check(CityLoader.load_cities("res://data/cities/nope.json").is_empty(), "missing city file returns {}")
	check(CityLoader.last_error != "", "missing city file sets last_error")
