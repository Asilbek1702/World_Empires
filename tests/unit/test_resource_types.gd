extends "res://tests/test_base.gd"


func _init() -> void:
	print("test_resource_types")
	check(ResourceTypes.NAMES.size() == ResourceTypes.Type.size(), "one name per resource type")
	check(ResourceTypes.Type.size() == 5, "the five state resources of the specification")
	check(ResourceTypes.display_name(ResourceTypes.Type.GOLD) == "Gold", "display name of gold")
	check(ResourceTypes.display_name(ResourceTypes.Type.MANPOWER) == "Manpower", "display name of manpower")
	check(ResourceTypes.is_valid(0) and ResourceTypes.is_valid(4), "first and last type are valid")
	check(not ResourceTypes.is_valid(-1) and not ResourceTypes.is_valid(5), "out of range types are invalid")
	check(ResourceTypes.display_name(99) == "?", "unknown type has a placeholder name")
	finish()
