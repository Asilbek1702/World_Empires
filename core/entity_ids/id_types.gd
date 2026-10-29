class_name IdTypes
extends RefCounted
## Entity ID format: "<prefix>_<number>", e.g. "region_00125".
## IDs are plain Strings (GDScript has no type aliases).
## The ID never depends on the current owner or name of the object.

enum Type { COUNTRY, REGION, CITY, ARMY, UNIT, GENERAL, BUILDING }

## Index in this array == value of Type.
const PREFIXES := ["country", "region", "city", "army", "unit", "general", "building"]


static func make(type: Type, number: int) -> String:
	return "%s_%05d" % [PREFIXES[type], number]


## Returns the Type value, or -1 if the id is invalid.
static func type_of(id: String) -> int:
	var split := id.rfind("_")
	if split <= 0 or _parse_digits(id) < 0:
		return -1
	var prefix := id.substr(0, split)
	for i in PREFIXES.size():
		if PREFIXES[i] == prefix:
			return i
	return -1


## Returns the numeric part, or -1 if the id is invalid.
static func number_of(id: String) -> int:
	if type_of(id) < 0:
		return -1
	return _parse_digits(id)


## type = -1 accepts any known type.
static func is_valid(id: String, type: int = -1) -> bool:
	var found := type_of(id)
	if found < 0:
		return false
	return type < 0 or found == type


static func _parse_digits(id: String) -> int:
	var split := id.rfind("_")
	if split <= 0:
		return -1
	var digits := id.substr(split + 1)
	if digits.is_empty() or not digits.is_valid_int():
		return -1
	if digits.begins_with("-") or digits.begins_with("+"):
		return -1
	return digits.to_int()
