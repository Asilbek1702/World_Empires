extends "res://tests/test_base.gd"


func _regions() -> Dictionary:
	var left := Region.from_static_dict({"id": "region_00001", "center": [50, 50], "terrain": "plains",
			"polygon": [[0, 0], [100, 0], [100, 100], [0, 100]], "neighbors": ["region_00002"]})
	var right := Region.from_static_dict({"id": "region_00002", "center": [150, 50], "terrain": "forest",
			"polygon": [[100, 0], [200, 0], [200, 100], [100, 100]], "neighbors": ["region_00001"]})
	return {left.id: left, right.id: right}


func _init() -> void:
	print("test_map_queries")
	_test_find_region_at()
	_test_bounds()
	_test_real_map_every_center_resolves_to_itself()
	finish()


func _test_find_region_at() -> void:
	var regions := _regions()
	check(MapQueries.find_region_at(regions, Vector2(50, 50)) == "region_00001", "point in the left region")
	check(MapQueries.find_region_at(regions, Vector2(150, 50)) == "region_00002", "point in the right region")
	check(MapQueries.find_region_at(regions, Vector2(500, 500)) == "", "point in the sea gives empty id")
	check(MapQueries.find_region_at({}, Vector2.ZERO) == "", "empty map gives empty id")


func _test_bounds() -> void:
	var bounds := MapQueries.compute_bounds(_regions())
	check(bounds == Rect2(0, 0, 200, 100), "bounds cover all polygons")
	check(MapQueries.compute_bounds({}) == Rect2(), "bounds of an empty map are empty")


func _test_real_map_every_center_resolves_to_itself() -> void:
	var regions := MapLoader.load_regions()
	var wrong := 0
	for id in regions:
		if MapQueries.find_region_at(regions, (regions[id] as Region).center) != id:
			wrong += 1
	check(wrong == 0, "clicking a region center selects that region (%d wrong)" % wrong)
	var bounds := MapQueries.compute_bounds(regions)
	check(bounds.has_area() and bounds.position.x >= 0.0 and bounds.end.x <= 1600.0, "real map bounds are inside the world rectangle")
