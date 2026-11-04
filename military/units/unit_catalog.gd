class_name UnitCatalog
extends RefCounted
## All unit types. Loaded once from data/units/units.json and cached.
## The UnitType objects are shared and must be treated as read-only.
## On failure get_all() is empty and last_error says why.

const DEFAULT_PATH := "res://data/units/units.json"
const FORMAT_VERSION := 1

static var last_error: String = ""
static var _cache: Dictionary = {}


static func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = load_unit_types(DEFAULT_PATH)
	return _cache


static func has(type_id: String) -> bool:
	return get_all().has(type_id)


## Returns null for an unknown id.
static func get_unit_type(type_id: String) -> UnitType:
	return get_all().get(type_id)


## Replaces the cache. For tests only.
static func override_for_tests(unit_types: Dictionary) -> void:
	_cache = unit_types


static func reset_cache() -> void:
	_cache = {}


## Reads a unit file. Returns id -> UnitType, or {} on any error (see last_error).
static func load_unit_types(path: String) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Unit file not found: %s" % path
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		last_error = "Unit file is not valid JSON (line %d): %s" % [
			json.get_error_line(), json.get_error_message()]
		return {}
	var root: Variant = json.data
	if not (root is Dictionary) or not (root.get("units") is Array):
		last_error = "Unit file has no units array"
		return {}
	if int(root.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "Unsupported unit format_version %s" % str(root.get("format_version"))
		return {}
	var unit_types := {}
	for entry in root["units"]:
		var unit_type := UnitType.from_dict(entry)
		if unit_type == null:
			last_error = "Malformed unit entry: %s" % str(entry).left(80)
			return {}
		if unit_types.has(unit_type.id):
			last_error = "Duplicate unit id %s" % unit_type.id
			return {}
		unit_types[unit_type.id] = unit_type
	if unit_types.is_empty():
		last_error = "Unit file has no units"
	return unit_types
