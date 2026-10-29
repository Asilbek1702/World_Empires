class_name CityLoader
extends RefCounted
## Loads the starting cities (data/cities/cities.json). Fresh City objects on every call.
## On failure returns {} and sets last_error.

const DEFAULT_PATH := "res://data/cities/cities.json"
const FORMAT_VERSION := 1

static var last_error: String = ""


static func load_cities(path: String = DEFAULT_PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "City file not found: %s" % path
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		last_error = "City file is not valid JSON (line %d): %s" % [
			json.get_error_line(), json.get_error_message()]
		return {}
	var root: Variant = json.data
	if not (root is Dictionary) or not (root.get("cities") is Array):
		last_error = "City file has no cities array"
		return {}
	if int(root.get("format_version", -1)) != FORMAT_VERSION:
		last_error = "Unsupported city format_version %s" % str(root.get("format_version"))
		return {}
	var cities := {}
	for entry in root["cities"]:
		var city := City.from_dict(entry)
		if city == null:
			last_error = "Malformed city entry: %s" % str(entry).left(80)
			return {}
		if cities.has(city.id):
			last_error = "Duplicate city id %s" % city.id
			return {}
		cities[city.id] = city
	if cities.is_empty():
		last_error = "City file has no cities"
	return cities


## Cross-checks the starting cities against the map and countries. Returns problems
## (empty = OK): every city is in a real region, at most one city per region,
## and every capital region has a city.
static func validate_against_map(cities: Dictionary, regions: Dictionary, countries: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var city_in_region := {}
	for cid in cities:
		var city: City = cities[cid]
		if not regions.has(city.region_id):
			problems.append("%s is in unknown region %s" % [cid, city.region_id])
		elif city_in_region.has(city.region_id):
			problems.append("%s and %s are both in %s" % [city_in_region[city.region_id], cid, city.region_id])
		city_in_region[city.region_id] = cid
	for country_id in countries:
		var capital: String = (countries[country_id] as Country).capital_region
		if not city_in_region.has(capital):
			problems.append("the capital region %s of %s has no city" % [capital, country_id])
	return problems
