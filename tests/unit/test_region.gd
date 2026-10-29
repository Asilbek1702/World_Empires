extends "res://tests/test_base.gd"


func _good() -> Dictionary:
	return {
		"id": "region_00007",
		"center": [10.5, 20.0],
		"terrain": "hills",
		"polygon": [[0, 0], [20, 0], [20, 40], [0, 40]],
		"neighbors": ["region_00008", "region_00009"],
	}


func _init() -> void:
	print("test_region")
	_test_from_static_dict()
	_test_rejects_bad_static_data()
	_test_terrain_table()
	_test_defaults_are_unowned()
	_test_area()
	_test_dynamic_roundtrip()
	_test_apply_dynamic_rejects_bad_data()
	finish()


func _test_from_static_dict() -> void:
	var r := Region.from_static_dict(_good())
	check(r != null, "valid static dict is accepted")
	check(r.id == "region_00007" and r.center == Vector2(10.5, 20.0), "id and center parsed")
	check(r.polygon.size() == 4 and r.polygon[2] == Vector2(20, 40), "polygon parsed")
	check(r.neighbors == ["region_00008", "region_00009"], "neighbors parsed")
	check(r.terrain == Region.Terrain.HILLS, "terrain parsed")


func _test_rejects_bad_static_data() -> void:
	check(Region.from_static_dict(null) == null, "null rejected")
	var d := _good()
	d["id"] = "city_00007"
	check(Region.from_static_dict(d) == null, "id of the wrong type rejected")
	d = _good()
	d.erase("id")
	check(Region.from_static_dict(d) == null, "missing id rejected")
	d = _good()
	d["terrain"] = "lava"
	check(Region.from_static_dict(d) == null, "unknown terrain rejected")
	d = _good()
	d["polygon"] = [[0, 0], [1, 1]]
	check(Region.from_static_dict(d) == null, "polygon with 2 points rejected")
	d = _good()
	d["polygon"] = [[0, 0], [1, 1], ["x", 2]]
	check(Region.from_static_dict(d) == null, "polygon with a non-number rejected")
	d = _good()
	d["center"] = [1]
	check(Region.from_static_dict(d) == null, "center with one value rejected")
	d = _good()
	d["neighbors"] = ["region_00008", 5]
	check(Region.from_static_dict(d) == null, "non-string neighbor rejected")


func _test_terrain_table() -> void:
	check(Region.TERRAIN_NAMES.size() == Region.Terrain.size(), "one name per Terrain value")


func _test_defaults_are_unowned() -> void:
	var r := Region.from_static_dict(_good())
	check(r.country_id == "" and r.population == 0 and r.resources.is_empty(), "new region is unowned, empty")


func _test_dynamic_roundtrip() -> void:
	var a := Region.from_static_dict(_good())
	a.country_id = "country_00002"
	a.population = 12345
	a.resources = {"iron": 3}
	var parsed: Variant = JSON.parse_string(JSON.stringify(a.dynamic_to_dict()))
	var b := Region.from_static_dict(_good())
	check(b.apply_dynamic(parsed), "apply_dynamic accepts parsed JSON")
	check(b.country_id == "country_00002" and b.population == 12345, "owner and population restored")
	check(b.resources.has("iron"), "resources restored")
	check(not a.dynamic_to_dict().has("polygon"), "static data is not part of the dynamic dict")
	a.resources["iron"] = 99
	check(int(b.resources["iron"]) == 3, "dynamic dict is a deep copy")
	check(b.resources == {"iron": 3}, "resources keep int values after JSON")


func _test_apply_dynamic_rejects_bad_data() -> void:
	var r := Region.from_static_dict(_good())
	r.country_id = "country_00001"
	r.population = 5
	check(not r.apply_dynamic({"country_id": 3, "population": 1, "resources": {}}), "numeric country_id rejected")
	check(not r.apply_dynamic({"country_id": "", "population": -1, "resources": {}}), "negative population rejected")
	check(not r.apply_dynamic({"country_id": "", "population": 1.5, "resources": {}}), "fractional population rejected")
	check(not r.apply_dynamic({"country_id": "", "population": 1, "resources": []}), "non-dictionary resources rejected")
	check(not r.apply_dynamic({"country_id": ""}), "missing fields rejected")
	check(not r.apply_dynamic(null), "null rejected")
	check(r.country_id == "country_00001" and r.population == 5, "rejected data changes nothing")


func _test_area() -> void:
	check(Region.polygon_area(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5), Vector2(0, 5)])) == 50.0, "area of a 10x5 rectangle")
	check(Region.polygon_area(PackedVector2Array([Vector2(0, 0), Vector2(0, 5), Vector2(10, 5), Vector2(10, 0)])) == 50.0, "area does not depend on vertex direction")
	check(Region.polygon_area(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(0, 3)])) == 6.0, "area of a 3-4-5 triangle")
	var r := Region.from_static_dict(_good())
	check(r.area == 800.0, "area is derived when the region is loaded (20 x 40)")
	check(not r.dynamic_to_dict().has("area"), "area is static data and is not saved")
