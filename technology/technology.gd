class_name Technology
extends RefCounted
## A technology (data/technologies/technologies.json). Immutable game data.
## cost: science points. requires: ids that must be researched first.
## output_modifiers: ResourceTypes.Type (int) -> fraction added to the output of that
## resource in EVERY region of the country, e.g. {SCIENCE: 0.2} = +20% science.
## Modifiers of one resource add up (with each other and with building modifiers).

const MAX_COST := 1000000
const MAX_REQUIRES := 8

var id: String = ""
var name: String = ""
var cost: int = 1
var requires: Array[String] = []
var output_modifiers: Dictionary = {}


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> Technology:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not _valid_id(d.get("id")):
		return null
	if not (d.get("name") is String) or (d["name"] as String).strip_edges() == "":
		return null
	var cost_value: Variant = d.get("cost")
	if not _is_whole(cost_value) or int(cost_value) < 1 or int(cost_value) > MAX_COST:
		return null
	var required: Variant = d.get("requires")
	if not (required is Array) or (required as Array).size() > MAX_REQUIRES:
		return null
	var modifiers: Variant = d.get("output_modifiers")
	if not (modifiers is Dictionary):
		return null

	var tech := Technology.new()
	tech.id = d["id"]
	tech.name = d["name"]
	tech.cost = int(cost_value)
	for entry in required:
		if not _valid_id(entry) or entry == tech.id or tech.requires.has(entry):
			return null
		tech.requires.append(entry)
	for key in modifiers:
		var type := ResourceTypes.type_from_key(str(key))
		var amount: Variant = modifiers[key]
		if type < 0 or not (typeof(amount) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(amount):
			return null
		if amount <= -1.0 or amount > 10.0:
			return null
		tech.output_modifiers[type] = float(amount)
	return tech


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
