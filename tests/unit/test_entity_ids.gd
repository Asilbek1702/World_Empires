extends "res://tests/test_base.gd"


func _init() -> void:
	print("test_entity_ids")
	_test_prefix_table()
	_test_make_format()
	_test_parse()
	_test_invalid_ids()
	_test_generator_sequence()
	_test_generator_types_independent()
	_test_observe()
	_test_dict_roundtrip()
	_test_json_roundtrip()
	finish()


func _test_prefix_table() -> void:
	check(IdTypes.PREFIXES.size() == IdTypes.Type.size(), "one prefix per Type value")


func _test_make_format() -> void:
	check(IdTypes.make(IdTypes.Type.REGION, 125) == "region_00125", "region id format")
	check(IdTypes.make(IdTypes.Type.ARMY, 3) == "army_00003", "army id format")
	check(IdTypes.make(IdTypes.Type.CITY, 123456) == "city_123456", "number wider than padding")


func _test_parse() -> void:
	check(IdTypes.type_of("region_00125") == IdTypes.Type.REGION, "type_of region")
	check(IdTypes.type_of("general_00001") == IdTypes.Type.GENERAL, "type_of general")
	check(IdTypes.number_of("region_00125") == 125, "number_of region_00125")
	check(IdTypes.is_valid("country_00001"), "valid country id")
	check(IdTypes.is_valid("country_00001", IdTypes.Type.COUNTRY), "valid with matching type")
	check(not IdTypes.is_valid("country_00001", IdTypes.Type.REGION), "invalid with wrong type")


func _test_invalid_ids() -> void:
	var bad := ["", "region", "region_", "_00001", "region_-1", "region_+1",
			"region_abc", "region_00001x", "foo_00001", "region00001"]
	var all_invalid := true
	for id in bad:
		if IdTypes.is_valid(id) or IdTypes.type_of(id) != -1 or IdTypes.number_of(id) != -1:
			all_invalid = false
			printerr("  accepted bad id: '%s'" % id)
	check(all_invalid, "malformed ids are rejected")


func _test_generator_sequence() -> void:
	var gen := IdGenerator.new()
	check(gen.next_id(IdTypes.Type.ARMY) == "army_00001", "first army id")
	check(gen.next_id(IdTypes.Type.ARMY) == "army_00002", "second army id")
	var seen := {}
	var unique := true
	for i in 100:
		var id := gen.next_id(IdTypes.Type.UNIT)
		if seen.has(id):
			unique = false
		seen[id] = true
	check(unique, "100 unit ids are unique")


func _test_generator_types_independent() -> void:
	var gen := IdGenerator.new()
	gen.next_id(IdTypes.Type.ARMY)
	gen.next_id(IdTypes.Type.ARMY)
	check(gen.next_id(IdTypes.Type.GENERAL) == "general_00001", "counters are per type")


func _test_observe() -> void:
	var gen := IdGenerator.new()
	gen.observe("region_00125")
	gen.observe("region_00007")
	gen.observe("garbage")
	check(gen.next_id(IdTypes.Type.REGION) == "region_00126", "observe raises the counter")
	check(gen.next_id(IdTypes.Type.CITY) == "city_00001", "observe ignores other types and garbage")


func _test_dict_roundtrip() -> void:
	var gen := IdGenerator.new()
	gen.next_id(IdTypes.Type.ARMY)
	gen.next_id(IdTypes.Type.ARMY)
	gen.next_id(IdTypes.Type.CITY)
	var copy := IdGenerator.new()
	copy.from_dict(gen.to_dict())
	check(copy.next_id(IdTypes.Type.ARMY) == "army_00003", "restored generator continues army ids")
	check(copy.next_id(IdTypes.Type.CITY) == "city_00002", "restored generator continues city ids")


func _test_json_roundtrip() -> void:
	var gen := IdGenerator.new()
	for i in 5:
		gen.next_id(IdTypes.Type.UNIT)
	var text := JSON.stringify(gen.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	var copy := IdGenerator.new()
	copy.from_dict(parsed)
	check(copy.next_id(IdTypes.Type.UNIT) == "unit_00006", "counters survive JSON (float -> int)")
