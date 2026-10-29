extends "res://tests/test_base.gd"


func _init() -> void:
	print("test_population_config")
	_test_table_matches_terrains()
	_test_hash_is_stable_and_in_range()
	_test_real_map()
	finish()


func _test_table_matches_terrains() -> void:
	check(PopulationConfig.DENSITY_PER_1000_AREA.size() == Region.Terrain.size(), "one density per terrain")
	check(PopulationConfig.START_VARIATION_MIN < PopulationConfig.START_VARIATION_MAX, "variation range is valid")
	check(PopulationConfig.CAPACITY_FACTOR > PopulationConfig.START_VARIATION_MAX, "capacity is above any starting population")


func _test_hash_is_stable_and_in_range() -> void:
	var a := PopulationConfig.variation("region_00042")
	check(a == PopulationConfig.variation("region_00042"), "the same id always gives the same factor")
	check(PopulationConfig.variation("region_00042") != PopulationConfig.variation("region_00043"), "different ids give different factors")
	# FNV-1a reference values: "" -> 2166136261, "a" -> 0xE40C292C
	check(PopulationConfig._hash01("") == 2166136261.0 / 4294967295.0, "FNV-1a of the empty string")
	check(PopulationConfig._hash01("a") == 0xE40C292C / 4294967295.0, "FNV-1a of 'a' matches the reference value")
	var in_range := true
	for i in 500:
		var v := PopulationConfig.variation("region_%05d" % i)
		if v < PopulationConfig.START_VARIATION_MIN or v > PopulationConfig.START_VARIATION_MAX:
			in_range = false
	check(in_range, "factors stay inside the variation range")


func _test_real_map() -> void:
	var regions := MapLoader.load_regions()
	var below_capacity := true
	var positive := true
	var sum_by_terrain := {}
	var count_by_terrain := {}
	var world := 0
	var smallest := 1 << 40
	var largest := 0
	for id in regions:
		var region: Region = regions[id]
		var start := PopulationConfig.initial_population(region)
		var cap := PopulationConfig.capacity(region)
		if start <= 0:
			positive = false
		if start >= cap:
			below_capacity = false
		sum_by_terrain[region.terrain] = sum_by_terrain.get(region.terrain, 0) + start
		count_by_terrain[region.terrain] = count_by_terrain.get(region.terrain, 0) + 1
		world += start
		smallest = mini(smallest, start)
		largest = maxi(largest, start)
	check(positive, "every region starts with people")
	check(below_capacity, "every region starts below its capacity (room to grow)")
	var avg_plains: float = sum_by_terrain[Region.Terrain.PLAINS] / float(count_by_terrain[Region.Terrain.PLAINS])
	var avg_desert: float = sum_by_terrain[Region.Terrain.DESERT] / float(count_by_terrain[Region.Terrain.DESERT])
	check(avg_plains > 3.0 * avg_desert, "plains are much more populated than desert (%d vs %d)" % [avg_plains, avg_desert])
	check(world > 10000000 and world < 100000000, "world population is plausible (%s)" % NumberFormat.thousands(world))
	check(largest < 10 * smallest + 1000000, "no region is absurdly larger than the others (%d..%d)" % [smallest, largest])
