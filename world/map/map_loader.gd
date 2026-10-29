class_name MapLoader
extends RefCounted
## Loads the static map (data/regions/regions.json) into fresh Region objects.
## Every call returns NEW instances, so two worlds never share a Region.
## On failure returns {} and sets last_error.

const DEFAULT_PATH := "res://data/regions/regions.json"
const FORMAT_VERSION := 1

static var last_error: String = ""


static func load_regions(path: String = DEFAULT_PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Map file not found: %s" % path
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		last_error = "Map file is not valid JSON (line %d): %s" % [
			json.get_error_line(), json.get_error_message()]
		return {}
	var root: Variant = json.data
	if not (root is Dictionary) or not (root.get("regions") is Array):
		last_error = "Map file has no regions array"
		return {}
	if int(root.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "Unsupported map format_version %s" % str(root.get("format_version"))
		return {}

	var regions := {}
	for entry in root["regions"]:
		var region := Region.from_static_dict(entry)
		if region == null:
			last_error = "Malformed region entry: %s" % str(entry).left(80)
			return {}
		if regions.has(region.id):
			last_error = "Duplicate region id %s" % region.id
			return {}
		regions[region.id] = region

	var problems := validate(regions)
	if not problems.is_empty():
		last_error = "Map is inconsistent: %s" % "; ".join(problems.slice(0, 5))
		return {}
	return regions


## Consistency check of a whole map. Returns a list of problems (empty = OK).
static func validate(regions: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if regions.is_empty():
		problems.append("map has no regions")
		return problems

	for id in regions:
		var region: Region = regions[id]
		if region.id != id:
			problems.append("key %s holds region %s" % [id, region.id])
		if region.neighbors.is_empty():
			problems.append("%s has no neighbors" % id)
		var seen := {}
		for neighbor_id in region.neighbors:
			if neighbor_id == id:
				problems.append("%s is its own neighbor" % id)
			elif not regions.has(neighbor_id):
				problems.append("%s lists unknown neighbor %s" % [id, neighbor_id])
			elif not (regions[neighbor_id] as Region).neighbors.has(id):
				problems.append("%s -> %s is not symmetric" % [id, neighbor_id])
			if seen.has(neighbor_id):
				problems.append("%s lists %s twice" % [id, neighbor_id])
			seen[neighbor_id] = true

	if problems.is_empty() and _count_reachable(regions) != regions.size():
		problems.append("neighbor graph is not connected")
	return problems


static func _count_reachable(regions: Dictionary) -> int:
	var start: String = regions.keys()[0]
	var visited := {start: true}
	var stack: Array[String] = [start]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		for neighbor_id in (regions[current] as Region).neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				stack.append(neighbor_id)
	return visited.size()
