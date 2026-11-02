extends "res://tests/test_base.gd"

const TMP := "user://_test_technologies.json"


func _good() -> Dictionary:
	return {"id": "irrigation", "name": "Irrigation", "cost": 1200, "requires": [],
			"output_modifiers": {"food": 0.15}}


func _tech(id: String, requires: Array, modifiers: Dictionary, cost: int = 100) -> Technology:
	return Technology.from_dict({"id": id, "name": id.capitalize(), "cost": cost,
			"requires": requires, "output_modifiers": modifiers})


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001


func _country(researched: Array) -> Country:
	var c := Country.from_start_dict({"id": "country_00001", "name": "T", "color": "#112233",
			"capital_region": "region_00001", "regions": ["region_00001"]})
	for id in researched:
		c.researched_technologies.append(id)
	return c


func _init() -> void:
	print("test_technology")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	TechnologyCatalog.reset_cache()
	_test_from_dict()
	_test_rejects_bad_data()
	_test_shipped_catalog()
	_test_loading_errors()
	_test_override_and_reset()
	_test_country_bonuses()
	_test_available_and_missing()
	_test_progress_math()
	_cleanup()
	TechnologyCatalog.reset_cache()
	finish()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _write(text: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_from_dict() -> void:
	var t := Technology.from_dict(_good())
	check(t != null, "valid technology is accepted")
	check(t.id == "irrigation" and t.name == "Irrigation" and t.cost == 1200, "fields parsed")
	check(t.requires.is_empty(), "no requirements")
	check(t.output_modifiers == {ResourceTypes.Type.FOOD: 0.15}, "modifier key 'food' becomes ResourceTypes.Type.FOOD")
	var d := _good()
	d["cost"] = 1200.0
	check(Technology.from_dict(d).cost == 1200, "cost as a whole float (JSON) is accepted")
	d = _good()
	d["requires"] = ["a", "b"]
	check(Technology.from_dict(d).requires == ["a", "b"], "requirements parsed")
	d = _good()
	d["output_modifiers"] = {}
	check(Technology.from_dict(d) != null, "a technology without modifiers is allowed")


func _test_rejects_bad_data() -> void:
	check(Technology.from_dict(null) == null, "null rejected")
	for bad_id in ["", "Irrigation", "1a", "a b", "a-b", "_a"]:
		var d := _good()
		d["id"] = bad_id
		check(Technology.from_dict(d) == null, "id '%s' rejected" % bad_id)
	var d := _good()
	d["name"] = "  "
	check(Technology.from_dict(d) == null, "blank name rejected")
	for bad_cost in [0, -3, 1.5, 1000001, "9", INF]:
		d = _good()
		d["cost"] = bad_cost
		check(Technology.from_dict(d) == null, "cost %s rejected" % str(bad_cost))
	d = _good()
	d["requires"] = "a"
	check(Technology.from_dict(d) == null, "requires that is not an array rejected")
	d = _good()
	d["requires"] = ["irrigation"]
	check(Technology.from_dict(d) == null, "requiring itself rejected")
	d = _good()
	d["requires"] = ["a", "a"]
	check(Technology.from_dict(d) == null, "a requirement twice rejected")
	d = _good()
	d["requires"] = ["Bad"]
	check(Technology.from_dict(d) == null, "a malformed requirement id rejected")
	d = _good()
	d["requires"] = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]
	check(Technology.from_dict(d) == null, "too many requirements rejected")
	d = _good()
	d["output_modifiers"] = []
	check(Technology.from_dict(d) == null, "modifiers that are not a dictionary rejected")
	d = _good()
	d["output_modifiers"] = {"wood": 0.1}
	check(Technology.from_dict(d) == null, "unknown resource rejected")
	d = _good()
	d["output_modifiers"] = {"food": "lots"}
	check(Technology.from_dict(d) == null, "non-numeric modifier rejected")
	d = _good()
	d["output_modifiers"] = {"food": -1.0}
	check(Technology.from_dict(d) == null, "a modifier of -100% or less rejected")
	d = _good()
	d["output_modifiers"] = {"food": 11.0}
	check(Technology.from_dict(d) == null, "an absurd modifier rejected")


func _test_shipped_catalog() -> void:
	var all := TechnologyCatalog.get_all()
	check(not all.is_empty(), "the shipped catalog loads (%s)" % TechnologyCatalog.last_error)
	check(all.size() >= 6 and all.size() <= 16, "6..16 technologies in the MVP (is %d)" % all.size())
	var ok := true
	var roots := 0
	for id in all:
		var t: Technology = all[id]
		if t.id != id or t.cost < 1 or t.output_modifiers.is_empty():
			ok = false
		if t.requires.is_empty():
			roots += 1
	check(ok, "every shipped technology has a cost and an effect")
	check(roots >= 2, "at least 2 technologies can be started at once (%d)" % roots)
	check(TechnologyCatalog.has("irrigation") and TechnologyCatalog.has("writing"), "irrigation and writing exist")
	check(TechnologyCatalog.get_technology("nope") == null and not TechnologyCatalog.has("nope"), "an unknown id gives null")
	check(TechnologyCatalog.get_all() == all, "get_all() is cached (same dictionary)")
	var fresh := TechnologyCatalog.load_technologies(TechnologyCatalog.DEFAULT_PATH)
	check(fresh["irrigation"] != all["irrigation"], "load_technologies() returns new objects every time")


func _entry(id: String, requires: String) -> String:
	return '{"id":"%s","name":"X","cost":10,"requires":[%s],"output_modifiers":{}}' % [id, requires]


func _test_loading_errors() -> void:
	check(TechnologyCatalog.load_technologies("res://data/technologies/nope.json").is_empty(), "missing file gives {}")
	check(TechnologyCatalog.last_error != "", "missing file sets last_error")
	_write("not json {{")
	check(TechnologyCatalog.load_technologies(TMP).is_empty(), "invalid JSON gives {}")
	_write('{"format_version": 1}')
	check(TechnologyCatalog.load_technologies(TMP).is_empty(), "no technologies array gives {}")
	_write('{"format_version": 99, "technologies": []}')
	check(TechnologyCatalog.load_technologies(TMP).is_empty(), "wrong format version gives {}")
	_write('{"format_version": 1, "technologies": []}')
	check(TechnologyCatalog.load_technologies(TMP).is_empty(), "an empty list gives {}")
	_write('{"format_version": 1, "technologies": [%s, %s]}' % [_entry("a", ""), _entry("a", "")])
	check(TechnologyCatalog.load_technologies(TMP).is_empty() and "Duplicate" in TechnologyCatalog.last_error, "a duplicate id gives {}")
	_write('{"format_version": 1, "technologies": [{"id": "x"}]}')
	check(TechnologyCatalog.load_technologies(TMP).is_empty() and "Malformed" in TechnologyCatalog.last_error, "a malformed entry gives {}")
	_write('{"format_version": 1, "technologies": [%s]}' % _entry("a", '"ghost"'))
	check(TechnologyCatalog.load_technologies(TMP).is_empty() and "unknown" in TechnologyCatalog.last_error, "an unknown requirement gives {}")
	_write('{"format_version": 1, "technologies": [%s, %s]}' % [_entry("a", '"b"'), _entry("b", '"a"')])
	check(TechnologyCatalog.load_technologies(TMP).is_empty() and "cycle" in TechnologyCatalog.last_error, "a requirement cycle gives {}")
	_write('{"format_version": 1, "technologies": [%s, %s, %s]}' % [_entry("a", ""), _entry("b", '"a"'), _entry("c", '"a","b"')])
	check(TechnologyCatalog.load_technologies(TMP).size() == 3, "a valid chain with a shared requirement loads")


func _test_override_and_reset() -> void:
	TechnologyCatalog.override_for_tests({"only": _tech("only", [], {})})
	check(TechnologyCatalog.has("only") and not TechnologyCatalog.has("irrigation"), "override replaces the catalog")
	TechnologyCatalog.reset_cache()
	check(TechnologyCatalog.has("irrigation") and not TechnologyCatalog.has("only"), "reset_cache() brings the shipped catalog back")


func _three() -> Dictionary:
	return {
		"a": _tech("a", [], {"food": 0.2}),
		"b": _tech("b", ["a"], {"food": 0.1, "gold": 0.3}),
		"c": _tech("c", ["a", "b"], {"science": 0.5}),
	}


func _test_country_bonuses() -> void:
	TechnologyCatalog.override_for_tests(_three())
	check(TechnologyModel.country_bonuses(_country([])).is_empty(), "no technologies, no bonuses")
	var one := TechnologyModel.country_bonuses(_country(["a"]))
	check(one.size() == 1 and _near(one[ResourceTypes.Type.FOOD], 0.2), "one technology: +20% food")
	var two := TechnologyModel.country_bonuses(_country(["a", "b"]))
	check(_near(two[ResourceTypes.Type.FOOD], 0.3) and _near(two[ResourceTypes.Type.GOLD], 0.3), "modifiers of one resource add up")
	check(TechnologyModel.country_bonuses(_country(["ghost"])).is_empty(), "an unknown technology id is ignored")
	TechnologyCatalog.reset_cache()


func _test_available_and_missing() -> void:
	TechnologyCatalog.override_for_tests(_three())
	check(TechnologyModel.available(_country([])) == ["a"], "at the start only the root is available")
	check(TechnologyModel.available(_country(["a"])) == ["b"], "after a: b (c still needs b)")
	check(TechnologyModel.available(_country(["a", "b"])) == ["c"], "after a and b: c")
	check(TechnologyModel.available(_country(["a", "b", "c"])).is_empty(), "everything researched: nothing left")
	var c_tech: Technology = TechnologyCatalog.get_technology("c")
	check(TechnologyModel.missing_requirements(_country(["a"]), c_tech) == ["b"], "missing_requirements lists what is absent")
	check(TechnologyModel.missing_requirements(_country(["a", "b"]), c_tech).is_empty(), "nothing missing when all are researched")
	TechnologyCatalog.reset_cache()


func _test_progress_math() -> void:
	check(TechnologyModel.next_progress(10.0, 5.5) == 15.5, "progress adds the science")
	check(TechnologyModel.next_progress(10.0, -4.0) == 10.0, "negative science adds nothing")
	check(TechnologyModel.next_progress(10.0, NAN) == 10.0 and TechnologyModel.next_progress(10.0, INF) == 10.0, "non-finite science is ignored")
	check(TechnologyModel.next_progress(0.0, 0.1 + 0.2) == 0.3, "progress is rounded to cents")
	check(TechnologyModel.seasons_left(0.0, 100, 30.0) == 4, "100 at 30 per season: 4 seasons")
	check(TechnologyModel.seasons_left(90.0, 100, 30.0) == 1, "10 left: 1 season")
	check(TechnologyModel.seasons_left(100.0, 100, 30.0) == 0, "nothing left: 0 seasons")
	check(TechnologyModel.seasons_left(0.0, 100, 0.0) == -1, "no science: never")
