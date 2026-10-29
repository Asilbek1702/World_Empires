extends "res://tests/test_base.gd"
## Tests the SHIPPED country file (data/countries/countries.json) against the shipped map.


func _init() -> void:
	print("test_country_data")
	var regions := MapLoader.load_regions()
	var countries := CountryLoader.load_countries()
	check(not countries.is_empty(), "countries load (%s)" % CountryLoader.last_error)
	if countries.is_empty() or regions.is_empty():
		finish()
		return
	_test_count_and_names(countries)
	_test_colors_distinct(countries)
	_test_consistent_with_map(countries, regions)
	_test_balanced(countries)
	_test_validator_catches_problems()
	_test_loads_are_independent()
	_test_missing_file()
	finish()


func _test_count_and_names(countries: Dictionary) -> void:
	check(countries.size() >= 4 and countries.size() <= 8, "4..8 countries (is %d)" % countries.size())
	var names := {}
	var ok := true
	for id in countries:
		var c: Country = countries[id]
		if c.name.strip_edges() == "" or names.has(c.name):
			ok = false
		names[c.name] = true
	check(ok, "names are non-empty and unique")


func _test_colors_distinct(countries: Dictionary) -> void:
	var ids: Array = countries.keys()
	var closest := 99.0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Color = (countries[ids[i]] as Country).color
			var b: Color = (countries[ids[j]] as Country).color
			closest = minf(closest, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	check(closest > 0.2, "country colors are clearly different (closest pair %.2f)" % closest)


func _test_consistent_with_map(countries: Dictionary, regions: Dictionary) -> void:
	var problems := CountryLoader.validate_against_map(countries, regions)
	check(problems.is_empty(), "every region has one owner, capitals inside, territories connected %s" % str(problems.slice(0, 3)))
	var total := 0
	for id in countries:
		total += (countries[id] as Country).regions.size()
	check(total == regions.size(), "country territories add up to the whole map (%d of %d)" % [total, regions.size()])


func _test_balanced(countries: Dictionary) -> void:
	var smallest := 9999
	var largest := 0
	for id in countries:
		var n: int = (countries[id] as Country).regions.size()
		smallest = mini(smallest, n)
		largest = maxi(largest, n)
	check(largest - smallest <= 6, "starting sizes are balanced (%d..%d)" % [smallest, largest])


func _line_map() -> Dictionary:
	# r1 - r2 - r3 in a row
	var out := {}
	var links := {"region_00001": ["region_00002"], "region_00002": ["region_00001", "region_00003"], "region_00003": ["region_00002"]}
	var x := 0.0
	for id in links:
		var r := Region.from_static_dict({"id": id, "center": [x + 1, 1], "terrain": "plains",
				"polygon": [[x, 0], [x + 2, 0], [x + 2, 2]], "neighbors": links[id]})
		out[id] = r
		x += 2.0
	return out


func _country(id: String, capital: String, region_ids: Array) -> Country:
	return Country.from_start_dict({"id": id, "name": "N" + id, "color": "#112233",
			"capital_region": capital, "regions": region_ids})


func _test_validator_catches_problems() -> void:
	var map := _line_map()
	var good := {
		"country_00001": _country("country_00001", "region_00001", ["region_00001", "region_00002"]),
		"country_00002": _country("country_00002", "region_00003", ["region_00003"]),
	}
	check(CountryLoader.validate_against_map(good, map).is_empty(), "baseline mini world is valid")

	var unknown := {"country_00001": _country("country_00001", "region_00001", ["region_00001", "region_00002", "region_00003", "region_00077"])}
	check(not CountryLoader.validate_against_map(unknown, map).is_empty(), "unknown region is caught")

	var twice := {
		"country_00001": _country("country_00001", "region_00001", ["region_00001", "region_00002"]),
		"country_00002": _country("country_00002", "region_00003", ["region_00002", "region_00003"]),
	}
	check(not CountryLoader.validate_against_map(twice, map).is_empty(), "region claimed twice is caught")

	var unclaimed := {"country_00001": _country("country_00001", "region_00001", ["region_00001", "region_00002"])}
	check(not CountryLoader.validate_against_map(unclaimed, map).is_empty(), "unclaimed region is caught")

	var split := {
		"country_00001": _country("country_00001", "region_00001", ["region_00001", "region_00003"]),
		"country_00002": _country("country_00002", "region_00002", ["region_00002"]),
	}
	check(not CountryLoader.validate_against_map(split, map).is_empty(), "disconnected territory is caught")


func _test_loads_are_independent() -> void:
	var one := CountryLoader.load_countries()
	var two := CountryLoader.load_countries()
	var id: String = one.keys()[0]
	(one[id] as Country).treasury = 5.0
	(one[id] as Country).regions.clear()
	check((two[id] as Country).treasury == 0.0 and not (two[id] as Country).regions.is_empty(), "two loads never share Country objects")


func _test_missing_file() -> void:
	check(CountryLoader.load_countries("res://data/countries/nope.json").is_empty(), "missing country file returns {}")
	check(CountryLoader.last_error != "", "missing country file sets last_error")
