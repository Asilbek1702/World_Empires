extends "res://tests/test_base.gd"


func _start() -> Dictionary:
	return {"id": "city_00007", "name": "Kaliburg", "region_id": "region_00012", "level": "town"}


func _order(id: String, total: int, done: int = 0) -> ConstructionOrder:
	var o := ConstructionOrder.new()
	o.building_id = id
	o.seasons_total = total
	o.seasons_done = done
	return o


func _init() -> void:
	print("test_city")
	_test_order()
	_test_order_rejects_bad_data()
	_test_city_from_start_dict()
	_test_city_rejects_bad_data()
	_test_level_table()
	_test_roundtrip()
	_test_queries()
	_test_construction_progress()
	_test_queue_is_sequential()
	finish()


func _test_order() -> void:
	var o := ConstructionOrder.from_dict({"building_id": "farm", "seasons_total": 3, "seasons_done": 1})
	check(o != null and o.seasons_left() == 2, "valid order, 2 seasons left")
	check(ConstructionOrder.from_dict(JSON.parse_string(JSON.stringify(o.to_dict()))).seasons_done == 1, "order survives JSON")


func _test_order_rejects_bad_data() -> void:
	check(ConstructionOrder.from_dict(null) == null, "null rejected")
	check(ConstructionOrder.from_dict({"building_id": "", "seasons_total": 3, "seasons_done": 0}) == null, "empty building id rejected")
	check(ConstructionOrder.from_dict({"building_id": "farm", "seasons_total": 0, "seasons_done": 0}) == null, "zero duration rejected")
	check(ConstructionOrder.from_dict({"building_id": "farm", "seasons_total": 3, "seasons_done": 3}) == null, "a finished order must not exist")
	check(ConstructionOrder.from_dict({"building_id": "farm", "seasons_total": 3, "seasons_done": -1}) == null, "negative progress rejected")
	check(ConstructionOrder.from_dict({"building_id": "farm", "seasons_total": 3.5, "seasons_done": 0}) == null, "fractional duration rejected")
	check(ConstructionOrder.from_dict({"building_id": "farm", "seasons_total": 3}) == null, "missing progress rejected")


func _test_city_from_start_dict() -> void:
	var c := City.from_dict(_start())
	check(c != null, "a start entry (no buildings, no queue) is accepted")
	check(c.id == "city_00007" and c.name == "Kaliburg" and c.region_id == "region_00012", "fields parsed")
	check(c.level == City.Level.TOWN and c.level_name() == "town", "level parsed")
	check(c.buildings.is_empty() and c.queue.is_empty(), "buildings and queue default to empty")


func _test_city_rejects_bad_data() -> void:
	check(City.from_dict(null) == null, "null rejected")
	var d := _start()
	d["id"] = "region_00007"
	check(City.from_dict(d) == null, "id of the wrong type rejected")
	d = _start()
	d["name"] = ""
	check(City.from_dict(d) == null, "empty name rejected")
	d = _start()
	d["region_id"] = "city_00001"
	check(City.from_dict(d) == null, "region id of the wrong type rejected")
	d = _start()
	d["level"] = "megacity"
	check(City.from_dict(d) == null, "unknown level rejected")
	d = _start()
	d["buildings"] = "farm"
	check(City.from_dict(d) == null, "buildings that are not an array rejected")
	d = _start()
	d["buildings"] = ["farm", "farm"]
	check(City.from_dict(d) == null, "a building twice rejected")
	d = _start()
	d["queue"] = [{"building_id": "farm", "seasons_total": 3, "seasons_done": 9}]
	check(City.from_dict(d) == null, "a broken queue entry rejected")


func _test_level_table() -> void:
	check(City.LEVEL_NAMES.size() == City.Level.size(), "one name per level")
	check(City.LEVEL_NAMES[0] == "village" and City.LEVEL_NAMES[5] == "metropolis", "from village to metropolis")


func _test_roundtrip() -> void:
	var a := City.from_dict(_start())
	a.buildings.append("farm")
	a.queue.append(_order("market", 4, 2))
	a.queue.append(_order("factory", 6, 0))
	var saved := a.to_dict()
	var b := City.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(b != null and b.to_dict() == saved, "city with buildings and queue survives JSON")
	check(b.queue.size() == 2 and b.queue[0].seasons_done == 2, "queue progress restored")
	a.buildings.append("factory")
	check(b.buildings.size() == 1, "to_dict copies the building list")


func _test_queries() -> void:
	var c := City.from_dict(_start())
	c.buildings.append("farm")
	c.queue.append(_order("market", 4))
	check(c.has_building("farm") and not c.has_building("market"), "has_building")
	check(c.is_queued("market") and not c.is_queued("farm"), "is_queued")


func _test_construction_progress() -> void:
	var c := City.from_dict(_start())
	check(c.advance_construction() == "", "an idle city has nothing to finish")
	c.queue.append(_order("farm", 3))
	check(c.advance_construction() == "" and c.queue[0].seasons_done == 1, "season 1 of 3")
	check(c.advance_construction() == "" and c.queue[0].seasons_done == 2, "season 2 of 3")
	check(c.buildings.is_empty(), "nothing is built before the duration is over")
	check(c.advance_construction() == "farm", "season 3 finishes the farm")
	check(c.buildings == ["farm"] and c.queue.is_empty(), "the farm is built once and the queue is empty")
	check(c.advance_construction() == "" and c.buildings == ["farm"], "nothing finishes twice")


func _test_queue_is_sequential() -> void:
	var c := City.from_dict(_start())
	c.queue.append(_order("farm", 2))
	c.queue.append(_order("market", 3))
	var finished: Array = []
	for season in 6:
		var done := c.advance_construction()
		if done != "":
			finished.append([season + 1, done])
		if season == 0:
			check(c.queue[1].seasons_done == 0, "the second order waits while the first runs")
	check(finished == [[2, "farm"], [5, "market"]], "farm after 2 seasons, market 3 seasons after that (%s)" % str(finished))
	check(c.buildings == ["farm", "market"], "buildings are listed in completion order")
