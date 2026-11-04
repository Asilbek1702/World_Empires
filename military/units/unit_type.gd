class_name UnitType
extends RefCounted
## A kind of unit (data/units/units.json). Immutable game data.
## manpower: people taken from the country's manpower stock. cost: gold, paid on recruiting.
## attack, defense, speed are used by later iterations (movement 13, battles 15).

const MAX_MANPOWER := 100000
const MAX_STAT := 1000

var id: String = ""
var name: String = ""
var manpower: int = 1
var cost: float = 0.0
var attack: int = 0
var defense: int = 0
var speed: int = 1


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> UnitType:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not _valid_id(d.get("id")):
		return null
	if not (d.get("name") is String) or (d["name"] as String).strip_edges() == "":
		return null
	var manpower_value: Variant = d.get("manpower")
	if not _is_whole(manpower_value) or int(manpower_value) < 1 or int(manpower_value) > MAX_MANPOWER:
		return null
	var cost_value: Variant = d.get("cost")
	if not (typeof(cost_value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(cost_value) or cost_value < 0:
		return null
	for key in ["attack", "defense"]:
		var stat: Variant = d.get(key)
		if not _is_whole(stat) or int(stat) < 0 or int(stat) > MAX_STAT:
			return null
	var speed_value: Variant = d.get("speed")
	if not _is_whole(speed_value) or int(speed_value) < 1 or int(speed_value) > MAX_STAT:
		return null

	var unit_type := UnitType.new()
	unit_type.id = d["id"]
	unit_type.name = d["name"]
	unit_type.manpower = int(manpower_value)
	unit_type.cost = EconomyModel.round_money(float(cost_value))
	unit_type.attack = int(d["attack"])
	unit_type.defense = int(d["defense"])
	unit_type.speed = int(speed_value)
	return unit_type


static func _valid_id(value: Variant) -> bool:
	if not (value is String) or (value as String).is_empty():
		return false
	var text: String = value
	if not (text[0] >= "a" and text[0] <= "z"):
		return false
	for character in text:
		var ok := (character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_"
		if not ok:
			return false
	return true


static func _is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)
