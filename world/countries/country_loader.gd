class_name CountryLoader
extends RefCounted
## Loads the starting countries (data/countries/countries.json).
## Every call returns NEW Country objects. On failure returns {} and sets last_error.

const DEFAULT_PATH := "res://data/countries/countries.json"
const FORMAT_VERSION := 1

static var last_error: String = ""


static func load_countries(path: String = DEFAULT_PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Country file not found: %s" % path
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		last_error = "Country file is not valid JSON (line %d): %s" % [
			json.get_error_line(), json.get_error_message()]
		return {}
	var root: Variant = json.data
	if not (root is Dictionary) or not (root.get("countries") is Array):
		last_error = "Country file has no countries array"
		return {}
	if int(root.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "Unsupported country format_version %s" % str(root.get("format_version"))
		return {}

	var countries := {}
	for entry in root["countries"]:
		var country := Country.from_start_dict(entry)
		if country == null:
			last_error = "Malformed country entry: %s" % str(entry).left(80)
			return {}
		if countries.has(country.id):
			last_error = "Duplicate country id %s" % country.id
			return {}
		countries[country.id] = country
	if countries.is_empty():
		last_error = "Country file has no countries"
	return countries


## Cross-checks starting countries against the map. Returns problems (empty = OK):
## every region claimed exactly once, capitals inside own territory,
## and every starting territory is one connected piece.
static func validate_against_map(countries: Dictionary, regions: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var claimed := {}
	for cid in countries:
		var country: Country = countries[cid]
		for rid in country.regions:
			if not regions.has(rid):
				problems.append("%s claims unknown region %s" % [cid, rid])
			elif claimed.has(rid):
				problems.append("%s is claimed by %s and %s" % [rid, claimed[rid], cid])
			claimed[rid] = cid
		if not country.regions.has(country.capital_region):
			problems.append("%s: capital %s is not in its territory" % [cid, country.capital_region])
		elif _count_connected(country, regions) != country.regions.size():
			problems.append("%s: territory is not connected" % cid)
	for rid in regions:
		if not claimed.has(rid):
			problems.append("%s belongs to nobody" % rid)
	return problems


static func _count_connected(country: Country, regions: Dictionary) -> int:
	var members := {}
	for rid in country.regions:
		members[rid] = true
	if not regions.has(country.capital_region):
		return 0
	var visited := {country.capital_region: true}
	var stack: Array[String] = [country.capital_region]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		for neighbor_id in (regions[current] as Region).neighbors:
			if members.has(neighbor_id) and not visited.has(neighbor_id):
				visited[neighbor_id] = true
				stack.append(neighbor_id)
	return visited.size()
