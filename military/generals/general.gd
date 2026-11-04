class_name General
extends RefCounted
## A general. Saved completely. Leads at most one army: army_id here and
## Army.general_id there always point at each other (WorldIntegrity checks it).
## Stats 1..100. They have no effect before battles (Iter 15).

const MAX_STAT := 100

var id: String = ""
var name: String = ""
var country_id: String = ""
var attack: int = 50
var defense: int = 50
var tactics: int = 50
var logistics: int = 50
var command: int = 50
var experience: int = 0
var army_id: String = ""  # "" = free


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "country_id": country_id,
		"attack": attack, "defense": defense, "tactics": tactics,
		"logistics": logistics, "command": command,
		"experience": experience, "army_id": army_id,
	}


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> General:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not (d.get("id") is String) or not IdTypes.is_valid(d["id"], IdTypes.Type.GENERAL):
		return null
	if not (d.get("name") is String) or (d["name"] as String).strip_edges() == "":
		return null
	if not (d.get("country_id") is String) or not IdTypes.is_valid(d["country_id"], IdTypes.Type.COUNTRY):
		return null
	for key in ["attack", "defense", "tactics", "logistics", "command"]:
		var stat: Variant = d.get(key)
		if not _is_whole(stat) or int(stat) < 1 or int(stat) > MAX_STAT:
			return null
	var xp: Variant = d.get("experience")
	if not _is_whole(xp) or int(xp) < 0:
		return null
	var army: Variant = d.get("army_id")
	if not (army is String) or (army != "" and not IdTypes.is_valid(army, IdTypes.Type.ARMY)):
		return null

	var general := General.new()
	general.id = d["id"]
	general.name = d["name"]
	general.country_id = d["country_id"]
	general.attack = int(d["attack"])
	general.defense = int(d["defense"])
	general.tactics = int(d["tactics"])
	general.logistics = int(d["logistics"])
	general.command = int(d["command"])
	general.experience = int(xp)
	general.army_id = army
	return general


static func _is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)
