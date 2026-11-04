class_name GeneralFactory
extends RefCounted
## The generals every country starts with. Fully determined by the country id
## (no RNG), so a new game always gets the same generals.

const PER_COUNTRY := 4
const FIRST := ["Aren", "Bors", "Cato", "Dorin", "Edric", "Falk", "Gareth", "Hakon", "Ivar", "Joren", "Kael", "Lorcan"]
const LAST := ["Vale", "Stone", "Marsh", "Crowe", "Hale", "Thorne", "Ward", "Reeve", "Brand", "Falke", "Gray", "Rook"]


## GeneralID -> General for all given countries. Ids are numbered in the order of the sorted country ids.
static func starting_generals(country_ids: Array) -> Dictionary:
	var sorted_ids := country_ids.duplicate()
	sorted_ids.sort()
	var out := {}
	var number := 0
	for country_id in sorted_ids:
		for index in PER_COUNTRY:
			number += 1
			var key := "%s:%d" % [country_id, index]
			var general := General.new()
			general.id = IdTypes.make(IdTypes.Type.GENERAL, number)
			general.country_id = country_id
			general.name = "%s %s" % [FIRST[_pick(key + ":first", FIRST.size())], LAST[_pick(key + ":last", LAST.size())]]
			general.attack = _stat(key + ":attack")
			general.defense = _stat(key + ":defense")
			general.tactics = _stat(key + ":tactics")
			general.logistics = _stat(key + ":logistics")
			general.command = _stat(key + ":command")
			out[general.id] = general
	return out


static func _pick(key: String, size: int) -> int:
	return mini(int(_hash01(key) * size), size - 1)


## 30..89
static func _stat(key: String) -> int:
	return 30 + mini(int(_hash01(key) * 60.0), 59)


## FNV-1a 32-bit. Stable on every platform.
static func _hash01(text: String) -> float:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h / 4294967295.0
