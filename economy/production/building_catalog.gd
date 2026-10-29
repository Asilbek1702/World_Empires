class_name BuildingCatalog
extends RefCounted
## All building types. Loaded once from data/buildings/buildings.json and cached.
## The Building objects are shared and must be treated as read-only.
## On failure get_all() is empty and last_error says why.

const DEFAULT_PATH := "res://data/buildings/buildings.json"
const FORMAT_VERSION := 1

static var last_error: String = ""
static var _cache: Dictionary = {}


static func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = load_buildings(DEFAULT_PATH)
	return _cache


static func has(building_id: String) -> bool:
	return get_all().has(building_id)


## Returns null for an unknown id.
static func get_building(building_id: String) -> Building:
	return get_all().get(building_id)


## Replaces the cache. For tests only.
static func override_for_tests(buildings: Dictionary) -> void:
	_cache = buildings


static func reset_cache() -> void:
	_cache = {}


## Reads a buildings file. Returns id -> Building, or {} on any error (see last_error).
static func load_buildings(path: String) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Building file not found: %s" % path
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		last_error = "Building file is not valid JSON (line %d): %s" % [
			json.get_error_line(), json.get_error_message()]
		return {}
	var root: Variant = json.data
	if not (root is Dictionary) or not (root.get("buildings") is Array):
		last_error = "Building file has no buildings array"
		return {}
	if int(root.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "Unsupported building format_version %s" % str(root.get("format_version"))
		return {}
	var buildings := {}
	for entry in root["buildings"]:
		var building := Building.from_dict(entry)
		if building == null:
			last_error = "Malformed building entry: %s" % str(entry).left(80)
			return {}
		if buildings.has(building.id):
			last_error = "Duplicate building id %s" % building.id
			return {}
		buildings[building.id] = building
	if buildings.is_empty():
		last_error = "Building file has no buildings"
	return buildings
