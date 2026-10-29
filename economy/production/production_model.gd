class_name ProductionModel
extends RefCounted
## What buildings do to output (pure functions).
##
##   region bonus of a resource = sum of that resource's modifiers over all buildings
##                                of all cities in the region
##   output = base output * (1 + bonus)          (see EconomyModel.region_output)


## ResourceTypes.Type (int) -> summed modifier of the completed buildings of one city.
static func city_bonuses(city: City, catalog: Dictionary = BuildingCatalog.get_all()) -> Dictionary:
	var bonuses := {}
	for building_id in city.buildings:
		var building: Building = catalog.get(building_id)
		if building == null:
			continue
		for type in building.output_modifiers:
			bonuses[type] = float(bonuses.get(type, 0.0)) + float(building.output_modifiers[type])
	return bonuses


## The same for a whole region (all its cities). Uses the derived Region.cities index.
static func region_bonuses(region: Region, cities: Dictionary,
		catalog: Dictionary = BuildingCatalog.get_all()) -> Dictionary:
	var bonuses := {}
	for city_id in region.cities:
		var city: City = cities.get(city_id)
		if city == null:
			continue
		var city_part := city_bonuses(city, catalog)
		for type in city_part:
			bonuses[type] = float(bonuses.get(type, 0.0)) + float(city_part[type])
	return bonuses
