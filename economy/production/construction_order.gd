class_name ConstructionOrder
extends RefCounted
## One building under construction in a city. The duration is copied from the
## building type when the order is placed, so later balance changes cannot
## shorten or lengthen a construction that is already running.

var building_id: String = ""
var seasons_total: int = 1
var seasons_done: int = 0


func seasons_left() -> int:
	return seasons_total - seasons_done


func to_dict() -> Dictionary:
	return {"building_id": building_id, "seasons_total": seasons_total, "seasons_done": seasons_done}


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> ConstructionOrder:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not (d.get("building_id") is String) or (d["building_id"] as String).is_empty():
		return null
	var total: Variant = d.get("seasons_total")
	var done: Variant = d.get("seasons_done")
	if not _is_whole(total) or not _is_whole(done):
		return null
	if int(total) < 1 or int(done) < 0 or int(done) >= int(total):
		return null
	var order := ConstructionOrder.new()
	order.building_id = d["building_id"]
	order.seasons_total = int(total)
	order.seasons_done = int(done)
	return order


static func _is_whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and value == floorf(value))
