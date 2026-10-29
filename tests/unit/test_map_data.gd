extends "res://tests/test_base.gd"
## Tests the SHIPPED map file (data/regions/regions.json).


func _init() -> void:
	print("test_map_data")
	var regions := MapLoader.load_regions()
	check(not regions.is_empty(), "map loads (%s)" % MapLoader.last_error)
	if regions.is_empty():
		finish()
		return
	_test_region_count(regions)
	_test_ids(regions)
	_test_neighbors_symmetric(regions)
	_test_graph_connected(regions)
	_test_geometry(regions)
	_test_terrain_variety(regions)
	_test_validator_accepts_shipped_map(regions)
	_test_validator_catches_problems()
	_test_loads_are_independent()
	_test_missing_file()
	finish()


func _test_region_count(regions: Dictionary) -> void:
	check(regions.size() >= 150 and regions.size() <= 300, "region count in 150..300 (is %d)" % regions.size())


func _test_ids(regions: Dictionary) -> void:
	var ok := true
	for id in regions:
		if not IdTypes.is_valid(id, IdTypes.Type.REGION) or (regions[id] as Region).id != id:
			ok = false
	check(ok, "every key is a valid region id equal to region.id")


func _test_neighbors_symmetric(regions: Dictionary) -> void:
	var asymmetric := 0
	var self_links := 0
	var isolated := 0
	for id in regions:
		var region: Region = regions[id]
		if region.neighbors.is_empty():
			isolated += 1
		for n in region.neighbors:
			if n == id:
				self_links += 1
			elif not (regions[n] as Region).neighbors.has(id):
				asymmetric += 1
	check(asymmetric == 0, "neighbor graph is symmetric (%d broken links)" % asymmetric)
	check(self_links == 0, "no region is its own neighbor")
	check(isolated == 0, "every region has at least one neighbor")


func _test_graph_connected(regions: Dictionary) -> void:
	var start: String = regions.keys()[0]
	var visited := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		for n in (regions[current] as Region).neighbors:
			if not visited.has(n):
				visited[n] = true
				stack.append(n)
	check(visited.size() == regions.size(), "one connected landmass")


func _test_geometry(regions: Dictionary) -> void:
	var bad_polygon := 0
	var center_outside := 0
	var degenerate := 0
	for id in regions:
		var region: Region = regions[id]
		if region.polygon.size() < 3:
			bad_polygon += 1
		if not Geometry2D.is_point_in_polygon(region.center, region.polygon):
			center_outside += 1
		var area := 0.0
		for i in region.polygon.size():
			var a := region.polygon[i]
			var b := region.polygon[(i + 1) % region.polygon.size()]
			area += a.x * b.y - b.x * a.y
		if absf(area) * 0.5 < 100.0:
			degenerate += 1
	check(bad_polygon == 0, "every polygon has at least 3 vertices")
	check(center_outside == 0, "every center lies inside its polygon")
	check(degenerate == 0, "no degenerate (tiny) regions")


func _test_terrain_variety(regions: Dictionary) -> void:
	var seen := {}
	for id in regions:
		seen[(regions[id] as Region).terrain] = true
	check(seen.size() == Region.Terrain.size(), "all terrain types are present")


func _test_validator_accepts_shipped_map(regions: Dictionary) -> void:
	check(MapLoader.validate(regions).is_empty(), "validator accepts the shipped map")


func _mini_map() -> Dictionary:
	var a := Region.from_static_dict({"id": "region_00001", "center": [1, 1], "terrain": "plains",
			"polygon": [[0, 0], [2, 0], [2, 2]], "neighbors": ["region_00002"]})
	var b := Region.from_static_dict({"id": "region_00002", "center": [3, 1], "terrain": "plains",
			"polygon": [[2, 0], [4, 0], [4, 2]], "neighbors": ["region_00001"]})
	return {a.id: a, b.id: b}


func _test_validator_catches_problems() -> void:
	check(MapLoader.validate(_mini_map()).is_empty(), "baseline mini map is valid")
	check(not MapLoader.validate({}).is_empty(), "empty map is invalid")

	var asym := _mini_map()
	(asym["region_00002"] as Region).neighbors.clear()
	check(not MapLoader.validate(asym).is_empty(), "asymmetric link is caught")

	var unknown := _mini_map()
	(unknown["region_00001"] as Region).neighbors.append("region_00099")
	check(not MapLoader.validate(unknown).is_empty(), "unknown neighbor is caught")

	var self_link := _mini_map()
	(self_link["region_00001"] as Region).neighbors.append("region_00001")
	check(not MapLoader.validate(self_link).is_empty(), "self neighbor is caught")

	var duplicate := _mini_map()
	(duplicate["region_00001"] as Region).neighbors.append("region_00002")
	check(not MapLoader.validate(duplicate).is_empty(), "duplicate neighbor is caught")

	var island := _mini_map()
	var c := Region.from_static_dict({"id": "region_00003", "center": [9, 9], "terrain": "plains",
			"polygon": [[8, 8], [10, 8], [10, 10]], "neighbors": ["region_00004"]})
	var d := Region.from_static_dict({"id": "region_00004", "center": [11, 9], "terrain": "plains",
			"polygon": [[10, 8], [12, 8], [12, 10]], "neighbors": ["region_00003"]})
	island[c.id] = c
	island[d.id] = d
	check(not MapLoader.validate(island).is_empty(), "disconnected landmass is caught")


func _test_loads_are_independent() -> void:
	var one := MapLoader.load_regions()
	var two := MapLoader.load_regions()
	var id: String = one.keys()[0]
	(one[id] as Region).population = 999
	(one[id] as Region).country_id = "country_00001"
	check((two[id] as Region).population == 0 and (two[id] as Region).country_id == "", "two loads never share Region objects")


func _test_missing_file() -> void:
	check(MapLoader.load_regions("res://data/regions/does_not_exist.json").is_empty(), "missing map file returns {}")
	check(MapLoader.last_error != "", "missing map file sets last_error")
