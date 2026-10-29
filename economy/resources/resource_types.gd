class_name ResourceTypes
extends RefCounted
## The five state resources (spec 1.14, reduced MVP set).
## Natural deposits (iron, coal, oil...) come later as Region.resources.

enum Type { GOLD, FOOD, INDUSTRY, SCIENCE, MANPOWER }

## Index in this array == value of Type.
const NAMES := ["Gold", "Food", "Industry", "Science", "Manpower"]


static func is_valid(type: int) -> bool:
	return type >= 0 and type < Type.size()


static func display_name(type: int) -> String:
	return NAMES[type] if is_valid(type) else "?"


## "food" -> Type.FOOD. Returns -1 for an unknown key. Used by data files.
static func type_from_key(key: String) -> int:
	for i in NAMES.size():
		if (NAMES[i] as String).to_lower() == key:
			return i
	return -1
