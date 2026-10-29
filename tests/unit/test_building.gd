extends "res://tests/test_base.gd"

const TMP := "user://_test_buildings.json"


func _good() -> Dictionary:
	return {"id": "farm", "name": "Farm", "cost": 150, "build_seasons": 3,
			"output_modifiers": {"food": 0.35}}


func _init() -> void:
	print("test_building")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	_test_from_dict()
	_test_rejects_bad_data()
	_test_shipped_catalog()
	_test_loading_errors()
	_test_override_and_reset()
	_cleanup()
	finish()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_from_dict() -> void:
	var b := Building.from_dict(_good())
	check(b != null, "valid building is accepted")
	check(b.id == "farm" and b.name == "Farm", "id and name parsed")
	check(b.cost == 150.0 and b.build_seasons == 3, "cost and build time parsed")
	check(b.output_modifiers == {ResourceTypes.Type.FOOD: 0.35}, "modifier key 'food' becomes ResourceTypes.Type.FOOD")
	var d := _good()
	d["cost"] = 150.004
	check(Building.from_dict(d).cost == 150.0, "cost is rounded to cents")
	d = _good()
	d["output_modifiers"] = {"gold": 0.25, "food": -0.5}
	check(Building.from_dict(d).output_modifiers.size() == 2, "several modifiers, a negative one is allowed")
	d = _good()
	d["output_modifiers"] = {}
	check(Building.from_dict(d) != null, "a building without modifiers is allowed")
	d = _good()
	d["build_seasons"] = 3.0
	check(Building.from_dict(d).build_seasons == 3, "build time as a whole float (JSON) is accepted")


func _test_rejects_bad_data() -> void:
	check(Building.from_dict(null) == null, "null rejected")
	for bad_id in ["", "Farm", "1farm", "far m", "far-m", "_farm"]:
		var d := _good()
		d["id"] = bad_id
		check(Building.from_dict(d) == null, "id '%s' rejected" % bad_id)
	var d := _good()
	d["id"] = 5
	check(Building.from_dict(d) == null, "numeric id rejected")
	d = _good()
	d["name"] = "  "
	check(Building.from_dict(d) == null, "blank name rejected")
	d = _good()
	d["cost"] = -1
	check(Building.from_dict(d) == null, "negative cost rejected")
	d = _good()
	d["cost"] = "cheap"
	check(Building.from_dict(d) == null, "text cost rejected")
	d = _good()
	d["cost"] = NAN
	check(Building.from_dict(d) == null, "NaN cost rejected")
	for bad_seasons in [0, -2, 1.5, 201, "3"]:
		d = _good()
		d["build_seasons"] = bad_seasons
		check(Building.from_dict(d) == null, "build time %s rejected" % str(bad_seasons))
	d = _good()
	d["output_modifiers"] = []
	check(Building.from_dict(d) == null, "modifiers that are not a dictionary rejected")
	d = _good()
	d["output_modifiers"] = {"wood": 0.1}
	check(Building.from_dict(d) == null, "unknown resource rejected")
	d = _good()
	d["output_modifiers"] = {"food": "lots"}
	check(Building.from_dict(d) == null, "non-numeric modifier rejected")
	d = _good()
	d["output_modifiers"] = {"food": -1.0}
	check(Building.from_dict(d) == null, "a modifier of -100% or less rejected")
	d = _good()
	d["output_modifiers"] = {"food": 11.0}
	check(Building.from_dict(d) == null, "an absurd modifier rejected")


func _test_shipped_catalog() -> void:
	BuildingCatalog.reset_cache()
	var all := BuildingCatalog.get_all()
	check(not all.is_empty(), "the shipped catalog loads (%s)" % BuildingCatalog.last_error)
	check(all.size() >= 2 and all.size() <= 5, "2..5 building types in the MVP (is %d)" % all.size())
	var ok := true
	for id in all:
		var b: Building = all[id]
		if b.id != id or b.cost <= 0.0 or b.build_seasons < 1 or b.output_modifiers.is_empty():
			ok = false
	check(ok, "every shipped building has a cost, a build time and an effect")
	check(BuildingCatalog.has("farm") and BuildingCatalog.has("market") and BuildingCatalog.has("factory"), "farm, market and factory exist")
	check(BuildingCatalog.get_building("nope") == null and not BuildingCatalog.has("nope"), "an unknown id gives null")
	check(BuildingCatalog.get_all() == all, "get_all() is cached (same dictionary)")
	var fresh := BuildingCatalog.load_buildings(BuildingCatalog.DEFAULT_PATH)
	check(fresh["farm"] != all["farm"], "load_buildings() returns new objects every time")
	var farm: Building = all["farm"]
	check(farm.output_modifiers.has(ResourceTypes.Type.FOOD), "the farm boosts food")
	check((all["market"] as Building).output_modifiers.has(ResourceTypes.Type.GOLD), "the market boosts gold")
	check((all["factory"] as Building).output_modifiers.has(ResourceTypes.Type.INDUSTRY), "the factory boosts industry")


func _test_loading_errors() -> void:
	check(BuildingCatalog.load_buildings("res://data/buildings/nope.json").is_empty(), "missing file gives {}")
	check(BuildingCatalog.last_error != "", "missing file sets last_error")
	_write("not json {{")
	check(BuildingCatalog.load_buildings(TMP).is_empty(), "invalid JSON gives {}")
	_write('{"format_version": 1}')
	check(BuildingCatalog.load_buildings(TMP).is_empty(), "no buildings array gives {}")
	_write('{"format_version": 99, "buildings": []}')
	check(BuildingCatalog.load_buildings(TMP).is_empty(), "wrong format version gives {}")
	var one := '{"id":"farm","name":"Farm","cost":1,"build_seasons":1,"output_modifiers":{}}'
	_write('{"format_version": 1, "buildings": [%s, %s]}' % [one, one])
	check(BuildingCatalog.load_buildings(TMP).is_empty() and "Duplicate" in BuildingCatalog.last_error, "a duplicate id gives {}")
	_write('{"format_version": 1, "buildings": [{"id": "x"}]}')
	check(BuildingCatalog.load_buildings(TMP).is_empty() and "Malformed" in BuildingCatalog.last_error, "a malformed entry gives {}")
	_write('{"format_version": 1, "buildings": [%s]}' % one)
	check(BuildingCatalog.load_buildings(TMP).size() == 1, "a valid file loads")


func _test_override_and_reset() -> void:
	BuildingCatalog.override_for_tests({"only": Building.from_dict({"id": "only", "name": "Only", "cost": 1, "build_seasons": 1, "output_modifiers": {}})})
	check(BuildingCatalog.has("only") and not BuildingCatalog.has("farm"), "override replaces the catalog")
	BuildingCatalog.reset_cache()
	check(BuildingCatalog.has("farm") and not BuildingCatalog.has("only"), "reset_cache() brings the shipped catalog back")
