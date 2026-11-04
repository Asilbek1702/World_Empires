class_name Unit
extends RefCounted
## One recruited unit. Saved completely. It stands in a region of its country until
## an army takes it (Army.units is the truth about who is in an army).

var id: String = ""
var type_id: String = ""
var country_id: String = ""
var region_id: String = ""


func to_dict() -> Dictionary:
	return {"id": id, "type_id": type_id, "country_id": country_id, "region_id": region_id}


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> Unit:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not (d.get("id") is String) or not IdTypes.is_valid(d["id"], IdTypes.Type.UNIT):
		return null
	if not (d.get("type_id") is String) or (d["type_id"] as String).is_empty():
		return null
	if not (d.get("country_id") is String) or not IdTypes.is_valid(d["country_id"], IdTypes.Type.COUNTRY):
		return null
	if not (d.get("region_id") is String) or not IdTypes.is_valid(d["region_id"], IdTypes.Type.REGION):
		return null
	var unit := Unit.new()
	unit.id = d["id"]
	unit.type_id = d["type_id"]
	unit.country_id = d["country_id"]
	unit.region_id = d["region_id"]
	return unit
