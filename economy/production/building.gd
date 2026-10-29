class_name Building
extends RefCounted
## A building type (data/buildings/buildings.json). Immutable game data.
## output_modifiers: ResourceTypes.Type (int) -> fraction of the region's BASE output
## of that resource, e.g. {FOOD: 0.35} = +35% food. Modifiers of one resource add up.

const MAX_SEASONS := 200

var id: String = ""
var name: String = ""
var cost: float = 0.0  # gold, paid when construction is ordered
var build_seasons: int = 1
var output_modifiers: Dictionary = {}


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> Building:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not _valid_id(d.get("id")):
		return null
	if not (d.get("name") is String) or (d["name"] as String).strip_edges() == "":
		return null
	var cost_value: Variant = d.get("cost")
	if not (typeof(cost_value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(cost_value) or cost_value < 0:
		return null
	var seasons: Variant = d.get("build_seasons")
	if not _is_whole(seasons) or int(seasons) < 1 or int(seasons) > MAX_SEASONS:
		return null
	var modifiers: Variant = d.get("output_modifiers")
	if not (modifiers is Dictionary):
		return null

	var building := Building.new()
	building.id = d["id"]
	building.name = d["name"]
	building.cost = EconomyModel.round_money(float(cost_value))
	building.build_seasons = int(seasons)
	for key in modifiers:
		var type := ResourceTypes.type_from_key(str(key))
		var amount: Variant = modifiers[key]
		if type < 0 or not (typeof(amount) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(amount):
			return null
		if amount <= -1.0 or amount > 10.0:
			return null
		building.output_modifiers[type] = float(amount)
	return building


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
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and value == floorf(value))
