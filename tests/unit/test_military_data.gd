extends "res://tests/test_base.gd"

const StateScript := preload("res://world/world_state.gd")


func _unit_dict() -> Dictionary:
	return {"id": "unit_00001", "type_id": "infantry", "country_id": "country_00001", "region_id": "region_00001"}


func _army_dict() -> Dictionary:
	return {"id": "army_00001", "name": "First", "country_id": "country_00001", "region_id": "region_00001",
			"units": ["unit_00001", "unit_00002"], "general_id": "", "supply": 100.0,
			"movement_target": "", "order": "none"}


func _general_dict() -> Dictionary:
	return {"id": "general_00001", "name": "Aren Vale", "country_id": "country_00001",
			"attack": 50, "defense": 60, "tactics": 70, "logistics": 40, "command": 80,
			"experience": 0, "army_id": ""}


func _init() -> void:
	print("test_military_data")
	_test_unit()
	_test_army()
	_test_general()
	_test_factory()
	_test_integrity()
	_test_fresh_world()
	finish()


func _test_unit() -> void:
	var u := Unit.from_dict(_unit_dict())
	check(u != null and u.id == "unit_00001" and u.type_id == "infantry", "a valid unit is accepted")
	check(Unit.from_dict(JSON.parse_string(JSON.stringify(u.to_dict()))).to_dict() == u.to_dict(), "a unit survives JSON")
	check(Unit.from_dict(null) == null, "null rejected")
	for key in ["id", "type_id", "country_id", "region_id"]:
		var d := _unit_dict()
		d.erase(key)
		check(Unit.from_dict(d) == null, "missing '%s' rejected" % key)
	var d := _unit_dict()
	d["id"] = "army_00001"
	check(Unit.from_dict(d) == null, "an id of the wrong type rejected")
	d = _unit_dict()
	d["region_id"] = "city_00001"
	check(Unit.from_dict(d) == null, "a region id of the wrong type rejected")


func _test_army() -> void:
	var a := Army.from_dict(_army_dict())
	check(a != null and a.units == ["unit_00001", "unit_00002"], "a valid army is accepted")
	check(a.general_id == "" and a.supply == 100.0 and a.order == "none", "placeholders parsed")
	a.general_id = "general_00003"
	var back := Army.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check(back != null and back.to_dict() == a.to_dict(), "an army survives JSON")
	a.units.append("unit_00009")
	check(back.units.size() == 2, "to_dict copies the unit list")
	var d := _army_dict()
	d["units"] = []
	check(Army.from_dict(d) == null, "an army without units rejected")
	d = _army_dict()
	var many: Array = []
	for i in Army.MAX_UNITS + 1:
		many.append(IdTypes.make(IdTypes.Type.UNIT, i + 1))
	d["units"] = many
	check(Army.from_dict(d) == null, "more than %d units rejected" % Army.MAX_UNITS)
	many.pop_back()
	d["units"] = many
	check(Army.from_dict(d) != null, "exactly %d units accepted" % Army.MAX_UNITS)
	d = _army_dict()
	d["units"] = ["unit_00001", "unit_00001"]
	check(Army.from_dict(d) == null, "a unit twice rejected")
	d = _army_dict()
	d["units"] = ["unit_00001", "region_00002"]
	check(Army.from_dict(d) == null, "a unit id of the wrong type rejected")
	d = _army_dict()
	d["name"] = "  "
	check(Army.from_dict(d) == null, "blank name rejected")
	d = _army_dict()
	d["name"] = "x".repeat(Army.MAX_NAME_LENGTH + 1)
	check(Army.from_dict(d) == null, "too long name rejected")
	d = _army_dict()
	d["general_id"] = "unit_00001"
	check(Army.from_dict(d) == null, "a general id of the wrong type rejected")
	d = _army_dict()
	d["supply"] = 101
	check(Army.from_dict(d) == null, "supply above 100 rejected")
	d = _army_dict()
	d["order"] = "charge"
	check(Army.from_dict(d) == null, "an unknown order rejected")
	d = _army_dict()
	d["movement_target"] = "city_00001"
	check(Army.from_dict(d) == null, "a movement target of the wrong type rejected")
	for key in _army_dict().keys():
		d = _army_dict()
		d.erase(key)
		check(Army.from_dict(d) == null, "missing '%s' rejected" % key)


func _test_general() -> void:
	var g := General.from_dict(_general_dict())
	check(g != null and g.name == "Aren Vale" and g.command == 80, "a valid general is accepted")
	check(General.from_dict(JSON.parse_string(JSON.stringify(g.to_dict()))).to_dict() == g.to_dict(), "a general survives JSON")
	for key in ["attack", "defense", "tactics", "logistics", "command"]:
		var d := _general_dict()
		d[key] = 0
		check(General.from_dict(d) == null, "%s 0 rejected" % key)
		d[key] = 101
		check(General.from_dict(d) == null, "%s 101 rejected" % key)
	var d := _general_dict()
	d["experience"] = -1
	check(General.from_dict(d) == null, "negative experience rejected")
	d = _general_dict()
	d["name"] = ""
	check(General.from_dict(d) == null, "empty name rejected")
	d = _general_dict()
	d["army_id"] = "unit_00001"
	check(General.from_dict(d) == null, "an army id of the wrong type rejected")
	for key in _general_dict().keys():
		d = _general_dict()
		d.erase(key)
		check(General.from_dict(d) == null, "missing '%s' rejected" % key)


func _test_factory() -> void:
	var ids := ["country_00002", "country_00001", "country_00003"]
	var a := GeneralFactory.starting_generals(ids)
	var b := GeneralFactory.starting_generals(ids)
	check(a.size() == 3 * GeneralFactory.PER_COUNTRY, "%d generals per country" % GeneralFactory.PER_COUNTRY)
	var same := true
	var valid := true
	var per_country := {}
	for id in a:
		var g: General = a[id]
		if g.to_dict() != (b[id] as General).to_dict():
			same = false
		if General.from_dict(g.to_dict()) == null or g.army_id != "":
			valid = false
		per_country[g.country_id] = int(per_country.get(g.country_id, 0)) + 1
	check(same, "the same countries always give the same generals")
	check(valid, "every starting general is valid and free")
	check(per_country == {"country_00001": 4, "country_00002": 4, "country_00003": 4}, "every country gets its own four")
	check(a.has("general_00001") and a.has("general_00012") and not a.has("general_00013"), "ids are numbered 1..12")
	check((a["general_00001"] as General).country_id == "country_00001", "numbering follows the sorted country ids")
	var other := GeneralFactory.starting_generals(["country_00001"])
	check((other["general_00001"] as General).to_dict() == (a["general_00001"] as General).to_dict(), "a country's generals do not depend on the other countries")
	var varied := {}
	for id in a:
		varied[(a[id] as General).attack] = true
	check(varied.size() > 3, "stats differ between generals")


func _world() -> Node:
	var s = StateScript.new()
	WorldBuilder.start_new_game(s, 1)
	return s


func _types() -> Dictionary:
	return UnitCatalog.get_all()


func _check(s: Node) -> Array[String]:
	return WorldIntegrity.check_military(s.countries, s.regions, s.units, s.armies, s.generals, _types())


func _fresh_unit(s: Node, id: String, country: String, region: String) -> Unit:
	var u := Unit.new()
	u.id = id
	u.type_id = "infantry"
	u.country_id = country
	u.region_id = region
	s.units[id] = u
	return u


func _army(s: Node, id: String, country: String, region: String, unit_ids: Array) -> Army:
	var a := Army.new()
	a.id = id
	a.name = id
	a.country_id = country
	a.region_id = region
	for uid in unit_ids:
		a.units.append(uid)
	s.armies[id] = a
	return a


func _test_integrity() -> void:
	var s = _world()
	var c1: Country = s.countries["country_00001"]
	var c2: Country = s.countries["country_00002"]
	var r1: String = c1.regions[0]
	var r2: String = c1.regions[1]
	check(_check(s).is_empty(), "a fresh world has consistent military data")

	_fresh_unit(s, "unit_00001", c1.id, r1)
	_fresh_unit(s, "unit_00002", c1.id, r1)
	var army := _army(s, "army_00001", c1.id, r1, ["unit_00001", "unit_00002"])
	check(_check(s).is_empty(), "a unit and an army are consistent")

	(s.units["unit_00001"] as Unit).type_id = "ghost"
	check(not _check(s).is_empty(), "an unknown unit type is caught")
	(s.units["unit_00001"] as Unit).type_id = "infantry"
	(s.units["unit_00001"] as Unit).country_id = "country_99999"
	check(not _check(s).is_empty(), "a unit of an unknown country is caught")
	(s.units["unit_00001"] as Unit).country_id = c1.id
	(s.units["unit_00001"] as Unit).region_id = "region_99999"
	check(not _check(s).is_empty(), "a unit in an unknown region is caught")
	(s.units["unit_00001"] as Unit).region_id = r1

	(s.units["unit_00002"] as Unit).country_id = c2.id
	check(not _check(s).is_empty(), "a foreign unit in an army is caught")
	(s.units["unit_00002"] as Unit).country_id = c1.id
	(s.units["unit_00002"] as Unit).region_id = r2
	check(not _check(s).is_empty(), "a unit outside the army's region is caught")
	(s.units["unit_00002"] as Unit).region_id = r1

	army.units.append("unit_00077")
	check(not _check(s).is_empty(), "an unknown unit in an army is caught")
	army.units.pop_back()
	_army(s, "army_00002", c1.id, r1, ["unit_00001"])
	check(not _check(s).is_empty(), "a unit in two armies is caught")
	s.armies.erase("army_00002")
	army.units.clear()
	check(not _check(s).is_empty(), "an empty army is caught")
	army.units.append("unit_00001")
	army.units.append("unit_00002")
	army.country_id = "country_99999"
	check(not _check(s).is_empty(), "an army of an unknown country is caught")
	army.country_id = c1.id
	army.region_id = "region_99999"
	check(not _check(s).is_empty(), "an army in an unknown region is caught")
	army.region_id = r1
	check(_check(s).is_empty(), "back to consistent")

	var general: General = s.generals.values()[0]
	check(general.country_id == "country_00001", "the first starting general serves country 1")
	army.general_id = general.id
	check(not _check(s).is_empty(), "an army whose general does not lead it is caught")
	general.army_id = army.id
	check(_check(s).is_empty(), "general and army pointing at each other are consistent")
	general.army_id = ""
	check(not _check(s).is_empty(), "a one-way link is caught")
	general.army_id = army.id
	general.country_id = c2.id
	check(not _check(s).is_empty(), "a general leading a foreign army is caught")
	general.country_id = c1.id
	army.general_id = ""
	check(not _check(s).is_empty(), "a general leading an army that does not name him is caught")
	general.army_id = "army_00099"
	check(not _check(s).is_empty(), "a general leading an unknown army is caught")
	general.army_id = ""
	army.general_id = "general_99999"
	check(not _check(s).is_empty(), "an army with an unknown general is caught")
	army.general_id = ""
	check(WorldIntegrity.check(s).is_empty(), "WorldIntegrity.check includes the military and is consistent again")
	s.free()


func _test_fresh_world() -> void:
	var s = _world()
	check(s.generals.size() == s.countries.size() * GeneralFactory.PER_COUNTRY, "a new game gives every country its generals")
	check(s.units.is_empty() and s.armies.is_empty(), "a new game has no units and no armies")
	check(s.id_generator.next_id(IdTypes.Type.GENERAL) == "general_%05d" % (s.generals.size() + 1), "new ids do not collide with the starting generals")
	var all_start := true
	for cid in s.countries:
		if (s.countries[cid] as Country).manpower != EconomyConfig.STARTING_MANPOWER:
			all_start = false
	check(all_start, "every country starts with the configured manpower")
	s.free()
