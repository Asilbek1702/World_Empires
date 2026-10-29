extends "res://tests/test_base.gd"


func _start() -> Dictionary:
	return {
		"id": "country_00002",
		"name": "Brevland",
		"color": "#2e86c1",
		"capital_region": "region_00005",
		"regions": ["region_00009", "region_00005", "region_00007"],
	}


func _init() -> void:
	print("test_country")
	_test_from_start_dict()
	_test_rejects_bad_start_data()
	_test_defaults()
	_test_dict_roundtrip()
	_test_from_dict_rejects_bad_data()
	finish()


func _test_from_start_dict() -> void:
	var c := Country.from_start_dict(_start())
	check(c != null, "valid start dict is accepted")
	check(c.id == "country_00002" and c.name == "Brevland", "id and name parsed")
	check(c.color == Color.html("#2e86c1"), "color parsed")
	check(c.capital_region == "region_00005", "capital parsed")
	check(c.regions == ["region_00005", "region_00007", "region_00009"], "regions parsed and sorted")


func _test_rejects_bad_start_data() -> void:
	check(Country.from_start_dict(null) == null, "null rejected")
	var d := _start()
	d["id"] = "region_00002"
	check(Country.from_start_dict(d) == null, "id of the wrong type rejected")
	d = _start()
	d["name"] = "   "
	check(Country.from_start_dict(d) == null, "blank name rejected")
	d = _start()
	d["color"] = "#zzzzzz"
	check(Country.from_start_dict(d) == null, "invalid color rejected")
	d = _start()
	d["capital_region"] = "region_00001"
	check(Country.from_start_dict(d) == null, "capital outside the territory rejected")
	d = _start()
	d["regions"] = []
	check(Country.from_start_dict(d) == null, "empty territory rejected")
	d = _start()
	d["regions"] = ["region_00005", "region_00005"]
	check(Country.from_start_dict(d) == null, "duplicate region rejected")
	d = _start()
	d["regions"] = ["region_00005", 7]
	check(Country.from_start_dict(d) == null, "non-string region rejected")


func _test_defaults() -> void:
	var c := Country.from_start_dict(_start())
	check(not c.is_player_controlled, "not player controlled by default")
	check(c.treasury == 0.0 and c.stability == 50.0 and c.power_score == 0.0, "placeholder numbers have defaults")
	check(c.technology_level.is_empty() and c.researched_technologies.is_empty(), "no technology yet")


func _test_dict_roundtrip() -> void:
	var a := Country.from_start_dict(_start())
	a.flag = "flags/x.png"
	a.treasury = 1234.5
	a.stability = 71.25
	a.power_score = 9.0
	a.technology_level = {"military": 2}
	a.researched_technologies = ["bronze_working", "writing"]
	a.is_player_controlled = true
	var saved := a.to_dict()
	check(not saved.has("regions"), "saved dict has no regions (derived data)")
	check(saved["color"] == "#2e86c1", "color is saved as #rrggbb")
	var b := Country.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(b != null, "from_dict accepts parsed JSON")
	check(b.to_dict() == saved, "round trip keeps every field")
	check(b.regions.is_empty(), "regions stay empty (WorldState rebuilds them)")
	check(b.is_player_controlled and b.treasury == 1234.5, "flags and numbers restored")
	a.researched_technologies.append("pottery")
	check(b.researched_technologies.size() == 2, "to_dict copies the technology list")


func _test_from_dict_rejects_bad_data() -> void:
	var good := Country.from_start_dict(_start()).to_dict()
	check(Country.from_dict(good) != null, "baseline dict is accepted")
	check(Country.from_dict(null) == null, "null rejected")
	for key in good.keys():
		var d := good.duplicate(true)
		d.erase(key)
		check(Country.from_dict(d) == null, "missing '%s' rejected" % key)
	var bad := good.duplicate(true)
	bad["is_player_controlled"] = "yes"
	check(Country.from_dict(bad) == null, "non-bool player flag rejected")
	bad = good.duplicate(true)
	bad["treasury"] = "rich"
	check(Country.from_dict(bad) == null, "non-numeric treasury rejected")
	bad = good.duplicate(true)
	bad["researched_technologies"] = ["ok", 5]
	check(Country.from_dict(bad) == null, "non-string technology rejected")
	bad = good.duplicate(true)
	bad["color"] = "blue-ish"
	check(Country.from_dict(bad) == null, "invalid color rejected")
	bad = good.duplicate(true)
	bad["name"] = ""
	check(Country.from_dict(bad) == null, "empty name rejected")
