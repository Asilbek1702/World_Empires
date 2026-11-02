class_name TechnologyCatalog
extends RefCounted
## All technologies. Loaded once from data/technologies/technologies.json and cached.
## The Technology objects are shared and must be treated as read-only.
## On failure get_all() is empty and last_error says why.
## A file is rejected if a technology requires an unknown one or the requirements form a cycle.

const DEFAULT_PATH := "res://data/technologies/technologies.json"
const FORMAT_VERSION := 1

static var last_error: String = ""
static var _cache: Dictionary = {}


static func get_all() -> Dictionary:
	if _cache.is_empty():
		_cache = load_technologies(DEFAULT_PATH)
	return _cache


static func has(technology_id: String) -> bool:
	return get_all().has(technology_id)


## Returns null for an unknown id.
static func get_technology(technology_id: String) -> Technology:
	return get_all().get(technology_id)


## Replaces the cache. For tests only.
static func override_for_tests(technologies: Dictionary) -> void:
	_cache = technologies


static func reset_cache() -> void:
	_cache = {}


## Reads a technology file. Returns id -> Technology, or {} on any error (see last_error).
static func load_technologies(path: String) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Technology file not found: %s" % path
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		last_error = "Technology file is not valid JSON (line %d): %s" % [
			json.get_error_line(), json.get_error_message()]
		return {}
	var root: Variant = json.data
	if not (root is Dictionary) or not (root.get("technologies") is Array):
		last_error = "Technology file has no technologies array"
		return {}
	if int(root.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "Unsupported technology format_version %s" % str(root.get("format_version"))
		return {}
	var technologies := {}
	for entry in root["technologies"]:
		var tech := Technology.from_dict(entry)
		if tech == null:
			last_error = "Malformed technology entry: %s" % str(entry).left(80)
			return {}
		if technologies.has(tech.id):
			last_error = "Duplicate technology id %s" % tech.id
			return {}
		technologies[tech.id] = tech
	if technologies.is_empty():
		last_error = "Technology file has no technologies"
		return {}
	var problem := _graph_problem(technologies)
	if problem != "":
		last_error = problem
		return {}
	return technologies


static func _graph_problem(technologies: Dictionary) -> String:
	for id in technologies:
		for required in (technologies[id] as Technology).requires:
			if not technologies.has(required):
				return "%s requires unknown technology %s" % [id, required]
	var visit_state := {}  # id -> 1 (on the current path), 2 (done)
	for id in technologies:
		if _has_cycle(id, technologies, visit_state):
			return "Technology requirements form a cycle through %s" % id
	return ""


static func _has_cycle(id: String, technologies: Dictionary, visit_state: Dictionary) -> bool:
	var mark: int = visit_state.get(id, 0)
	if mark == 2:
		return false
	if mark == 1:
		return true
	visit_state[id] = 1
	for required in (technologies[id] as Technology).requires:
		if _has_cycle(required, technologies, visit_state):
			return true
	visit_state[id] = 2
	return false
