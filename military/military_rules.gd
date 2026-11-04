class_name MilitaryRules
extends RefCounted
## The rules of recruiting, forming armies and naming generals. One rule set, used by the
## commands (to accept or reject) and by the army panel (to enable or disable buttons).
## Every *_problem() returns "" if the action is allowed, otherwise the reason it is not.
## source_country "" means a system/debug action: any country may be used.


static func recruit_problem(state, city_id: String, type_id: String, source_country: String) -> String:
	if not state.cities.has(city_id):
		return "Unknown city %s" % city_id
	var unit_type := UnitCatalog.get_unit_type(type_id)
	if unit_type == null:
		return "Unknown unit type %s" % type_id
	var city: City = state.cities[city_id]
	var region: Region = state.regions.get(city.region_id)
	if region == null or not state.countries.has(region.country_id):
		return "%s has no owner" % city.name
	if source_country != "" and region.country_id != source_country:
		return "%s is not your city" % city.name
	var country: Country = state.countries[region.country_id]
	if country.manpower < float(unit_type.manpower):
		return "Not enough manpower: %s needs %s, you have %s" % [
			unit_type.name, NumberFormat.thousands(unit_type.manpower),
			NumberFormat.thousands(int(country.manpower))]
	if country.treasury < unit_type.cost:
		return "Not enough gold: %s costs %s, you have %s" % [
			unit_type.name, NumberFormat.thousands(int(ceil(unit_type.cost))),
			NumberFormat.thousands(int(country.treasury))]
	return ""


static func army_problem(state, region_id: String, unit_ids: Array, source_country: String) -> String:
	if not state.regions.has(region_id):
		return "Unknown region %s" % region_id
	if unit_ids.is_empty():
		return "Choose at least one unit"
	if unit_ids.size() > Army.MAX_UNITS:
		return "An army holds at most %d units" % Army.MAX_UNITS
	var assigned := units_in_armies(state)
	var seen := {}
	var country_id := ""
	for unit_id in unit_ids:
		if not (unit_id is String) or not state.units.has(unit_id):
			return "Unknown unit %s" % str(unit_id)
		if seen.has(unit_id):
			return "%s is listed twice" % unit_id
		seen[unit_id] = true
		var unit: Unit = state.units[unit_id]
		if assigned.has(unit_id):
			return "%s is already in an army" % unit_id
		if unit.region_id != region_id:
			return "%s is not in %s" % [unit_id, region_id]
		if source_country != "" and unit.country_id != source_country:
			return "%s is not your unit" % unit_id
		if country_id == "":
			country_id = unit.country_id
		elif unit.country_id != country_id:
			return "An army holds units of one country only"
	return ""


static func general_problem(state, army_id: String, general_id: String, source_country: String) -> String:
	if not state.armies.has(army_id):
		return "Unknown army %s" % army_id
	if not state.generals.has(general_id):
		return "Unknown general %s" % general_id
	var army: Army = state.armies[army_id]
	var general: General = state.generals[general_id]
	if source_country != "" and army.country_id != source_country:
		return "%s is not your army" % army.name
	if general.country_id != army.country_id:
		return "%s serves another country" % general.name
	if general.army_id == army_id:
		return "%s already leads %s" % [general.name, army.name]
	if general.army_id != "":
		return "%s already leads another army" % general.name
	return ""


## Sorted ids of the units that are in no army, optionally only those of one country / region.
static func free_units(state, country_id: String = "", region_id: String = "") -> Array[String]:
	var assigned := units_in_armies(state)
	var out: Array[String] = []
	for unit_id in state.units:
		var unit: Unit = state.units[unit_id]
		if assigned.has(unit_id):
			continue
		if country_id != "" and unit.country_id != country_id:
			continue
		if region_id != "" and unit.region_id != region_id:
			continue
		out.append(unit_id)
	out.sort()
	return out


## Sorted ids of the generals of a country that lead no army.
static func free_generals(state, country_id: String) -> Array[String]:
	var out: Array[String] = []
	for general_id in state.generals:
		var general: General = state.generals[general_id]
		if general.country_id == country_id and general.army_id == "":
			out.append(general_id)
	out.sort()
	return out


## UnitID -> true for every unit that is in an army.
static func units_in_armies(state) -> Dictionary:
	var assigned := {}
	for army_id in state.armies:
		for unit_id in (state.armies[army_id] as Army).units:
			assigned[unit_id] = true
	return assigned
