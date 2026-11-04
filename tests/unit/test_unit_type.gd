extends "res://tests/test_base.gd"

const TMP := "user://_test_units.json"


func _good() -> Dictionary:
	return {"id": "infantry", "name": "Infantry", "manpower": 1000, "cost": 100,
			"attack": 10, "defense": 12, "speed": 3}


func _init() -> void:
	print("test_unit_type")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	UnitCatalog.reset_cache()
	_test_from_dict()
	_test_rejects_bad_data()
	_test_shipped_catalog()
	_test_loading_errors()
	_test_override_and_reset()
	_cleanup()
	UnitCatalog.reset_cache()
	finish()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_from_dict() -> void:
	var t := UnitType.from_dict(_good())
	check(t != null, "valid unit type is accepted")
	check(t.id == "infantry" and t.name == "Infantry", "id and name parsed")
	check(t.manpower == 1000 and t.cost == 100.0, "manpower and cost parsed")
	check(t.attack == 10 and t.defense == 12 and t.speed == 3, "stats parsed")
	var d := _good()
	d["manpower"] = 1000.0
	d["cost"] = 100.004
	var rounded := UnitType.from_dict(d)
	check(rounded.manpower == 1000 and rounded.cost == 100.0, "whole float manpower accepted, cost rounded to cents")
	d = _good()
	d["attack"] = 0
	check(UnitType.from_dict(d) != null, "attack 0 is allowed")


func _test_rejects_bad_data() -> void:
	check(UnitType.from_dict(null) == null, "null rejected")
	for bad_id in ["", "Infantry", "1a", "a b", "_a"]:
		var d := _good()
		d["id"] = bad_id
		check(UnitType.from_dict(d) == null, "id '%s' rejected" % bad_id)
	var d := _good()
	d["name"] = " "
	check(UnitType.from_dict(d) == null, "blank name rejected")
	for bad_manpower in [0, -5, 1.5, 100001, "9", INF]:
		d = _good()
		d["manpower"] = bad_manpower
		check(UnitType.from_dict(d) == null, "manpower %s rejected" % str(bad_manpower))
	for bad_cost in [-1, "cheap", NAN]:
		d = _good()
		d["cost"] = bad_cost
		check(UnitType.from_dict(d) == null, "cost %s rejected" % str(bad_cost))
	for key in ["attack", "defense"]:
		d = _good()
		d[key] = -1
		check(UnitType.from_dict(d) == null, "negative %s rejected" % key)
		d = _good()
		d[key] = 1.5
		check(UnitType.from_dict(d) == null, "fractional %s rejected" % key)
	d = _good()
	d["speed"] = 0
	check(UnitType.from_dict(d) == null, "speed 0 rejected")
	for key in ["id", "name", "manpower", "cost", "attack", "defense", "speed"]:
		d = _good()
		d.erase(key)
		check(UnitType.from_dict(d) == null, "missing '%s' rejected" % key)


func _test_shipped_catalog() -> void:
	var all := UnitCatalog.get_all()
	check(not all.is_empty(), "the shipped catalog loads (%s)" % UnitCatalog.last_error)
	check(all.size() >= 3 and all.size() <= 5, "3..5 unit types in the MVP (is %d)" % all.size())
	check(UnitCatalog.has("infantry") and UnitCatalog.has("cavalry") and UnitCatalog.has("artillery"), "infantry, cavalry and artillery exist")
	var ok := true
	for id in all:
		var t: UnitType = all[id]
		if t.id != id or t.manpower < 1 or t.cost <= 0.0 or t.speed < 1:
			ok = false
	check(ok, "every shipped unit type has manpower, a cost and a speed")
	check((all["cavalry"] as UnitType).speed > (all["infantry"] as UnitType).speed, "cavalry is faster than infantry")
	check((all["infantry"] as UnitType).manpower == 1000 and (all["cavalry"] as UnitType).manpower == 500, "infantry is 1000 men, cavalry 500 (spec 13.4)")
	check(UnitCatalog.get_unit_type("nope") == null and not UnitCatalog.has("nope"), "an unknown id gives null")
	check(UnitCatalog.get_all() == all, "get_all() is cached (same dictionary)")
	var fresh := UnitCatalog.load_unit_types(UnitCatalog.DEFAULT_PATH)
	check(fresh["infantry"] != all["infantry"], "load_unit_types() returns new objects every time")


func _test_loading_errors() -> void:
	check(UnitCatalog.load_unit_types("res://data/units/nope.json").is_empty(), "missing file gives {}")
	check(UnitCatalog.last_error != "", "missing file sets last_error")
	_write("not json {{")
	check(UnitCatalog.load_unit_types(TMP).is_empty(), "invalid JSON gives {}")
	_write('{"format_version": 1}')
	check(UnitCatalog.load_unit_types(TMP).is_empty(), "no units array gives {}")
	_write('{"format_version": 99, "units": []}')
	check(UnitCatalog.load_unit_types(TMP).is_empty(), "wrong format version gives {}")
	_write('{"format_version": 1, "units": []}')
	check(UnitCatalog.load_unit_types(TMP).is_empty(), "an empty list gives {}")
	var one := '{"id":"a","name":"A","manpower":10,"cost":1,"attack":1,"defense":1,"speed":1}'
	_write('{"format_version": 1, "units": [%s, %s]}' % [one, one])
	check(UnitCatalog.load_unit_types(TMP).is_empty() and "Duplicate" in UnitCatalog.last_error, "a duplicate id gives {}")
	_write('{"format_version": 1, "units": [{"id": "x"}]}')
	check(UnitCatalog.load_unit_types(TMP).is_empty() and "Malformed" in UnitCatalog.last_error, "a malformed entry gives {}")
	_write('{"format_version": 1, "units": [%s]}' % one)
	check(UnitCatalog.load_unit_types(TMP).size() == 1, "a valid file loads")


func _test_override_and_reset() -> void:
	UnitCatalog.override_for_tests({"only": UnitType.from_dict({"id": "only", "name": "Only", "manpower": 1,
			"cost": 1, "attack": 1, "defense": 1, "speed": 1})})
	check(UnitCatalog.has("only") and not UnitCatalog.has("infantry"), "override replaces the catalog")
	UnitCatalog.reset_cache()
	check(UnitCatalog.has("infantry") and not UnitCatalog.has("only"), "reset_cache() brings the shipped catalog back")
