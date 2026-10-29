class_name Country
extends RefCounted
## A state. Saved COMPLETELY (name, color too), because countries can be created
## and destroyed during a campaign, so they cannot all come from a static file.
##
## `regions` is a derived index of the regions this country owns.
## It is NOT saved: it is rebuilt from Region.country_id on load, so it can never
## disagree with the map. WorldState keeps it in sync (see set_region_owner).

var id: String = ""
var name: String = ""
var flag: String = ""  # reserved, no flags in the MVP
var color: Color = Color.WHITE
var capital_region: String = ""
var regions: Array[String] = []  # sorted, derived

# Placeholders filled by later iterations (economy 9, technology 11).
var treasury: float = 0.0  # gold, always whole cents (EconomyModel.round_money)
var technology_level: Dictionary = {}
var researched_technologies: Array[String] = []
var stability: float = 50.0
var power_score: float = 0.0

var is_player_controlled: bool = false


## Parses one entry of data/countries/countries.json. Returns null if malformed.
static func from_start_dict(data: Variant) -> Country:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not _valid_id(d.get("id")):
		return null
	if not (d.get("name") is String) or (d["name"] as String).strip_edges() == "":
		return null
	if not (d.get("color") is String) or not Color.html_is_valid(d["color"]):
		return null
	if not (d.get("capital_region") is String):
		return null
	var region_list: Variant = d.get("regions")
	if not (region_list is Array) or (region_list as Array).is_empty():
		return null

	var country := Country.new()
	country.id = d["id"]
	country.name = d["name"]
	country.color = Color.html(d["color"])
	country.capital_region = d["capital_region"]
	for region_id in region_list:
		if not (region_id is String) or country.regions.has(region_id):
			return null
		country.regions.append(region_id)
	if not country.regions.has(country.capital_region):
		return null
	country.regions.sort()
	return country


## Full saved state. `regions` is deliberately absent (derived).
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"flag": flag,
		"color": "#" + color.to_html(false),
		"capital_region": capital_region,
		"treasury": treasury,
		"technology_level": JsonNumbers.canonical(technology_level),
		"researched_technologies": researched_technologies.duplicate(),
		"stability": stability,
		"power_score": power_score,
		"is_player_controlled": is_player_controlled,
	}


## Returns null if malformed. `regions` stays empty: WorldState rebuilds it.
static func from_dict(data: Variant) -> Country:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not _valid_id(d.get("id")):
		return null
	for key in ["name", "flag", "capital_region"]:
		if not (d.get(key) is String):
			return null
	if (d["name"] as String).strip_edges() == "":
		return null
	if not (d.get("color") is String) or not Color.html_is_valid(d["color"]):
		return null
	for key in ["treasury", "stability", "power_score"]:
		if not (typeof(d.get(key)) in [TYPE_INT, TYPE_FLOAT]):
			return null
	if not (d.get("technology_level") is Dictionary):
		return null
	var techs: Variant = d.get("researched_technologies")
	if not (techs is Array):
		return null
	for tech in techs:
		if not (tech is String):
			return null
	if not (d.get("is_player_controlled") is bool):
		return null

	var country := Country.new()
	country.id = d["id"]
	country.name = d["name"]
	country.flag = d["flag"]
	country.color = Color.html(d["color"])
	country.capital_region = d["capital_region"]
	country.treasury = float(d["treasury"])
	country.technology_level = JsonNumbers.canonical(d["technology_level"])
	for tech in techs:
		country.researched_technologies.append(tech)
	country.stability = float(d["stability"])
	country.power_score = float(d["power_score"])
	country.is_player_controlled = d["is_player_controlled"]
	return country


static func _valid_id(value: Variant) -> bool:
	return value is String and IdTypes.is_valid(value, IdTypes.Type.COUNTRY)
