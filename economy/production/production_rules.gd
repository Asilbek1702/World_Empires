class_name ProductionRules
extends RefCounted
## Who may order which building. One rule set, used by BuildBuildingCommand (to
## accept or reject) and by the city panel (to enable or disable the buttons).

const MAX_QUEUE_SIZE := 3


## Returns "" if the building can be ordered, otherwise the reason it cannot.
## source_country "" means a system/debug order: any city may be used.
static func build_problem(state, city_id: String, building_id: String, source_country: String) -> String:
	if not state.cities.has(city_id):
		return "Unknown city %s" % city_id
	var building := BuildingCatalog.get_building(building_id)
	if building == null:
		return "Unknown building %s" % building_id
	var city: City = state.cities[city_id]
	var region: Region = state.regions.get(city.region_id)
	if region == null or not state.countries.has(region.country_id):
		return "%s has no owner" % city.name
	if source_country != "" and region.country_id != source_country:
		return "%s is not your city" % city.name
	if city.has_building(building_id):
		return "%s already has a %s" % [city.name, building.name]
	if city.is_queued(building_id):
		return "%s is already being built in %s" % [building.name, city.name]
	if city.queue.size() >= MAX_QUEUE_SIZE:
		return "The construction queue of %s is full" % city.name
	var treasury: float = (state.countries[region.country_id] as Country).treasury
	if treasury < building.cost:
		return "Not enough gold: %s costs %s, you have %s" % [
			building.name, NumberFormat.thousands(int(ceil(building.cost))),
			NumberFormat.thousands(int(treasury))]
	return ""
