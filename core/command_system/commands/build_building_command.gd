class_name BuildBuildingCommand
extends Command
## Orders a building in a city. The cost is paid at once from the owner's treasury,
## the order joins the city's queue and finishes after the building's build time.
## All rules live in ProductionRules.

var city_id: String = ""
var building_id: String = ""


func _init(p_city_id: String = "", p_building_id: String = "", p_source_country: String = "") -> void:
	city_id = p_city_id
	building_id = p_building_id
	source_country = p_source_country


func get_command_name() -> String:
	return "BuildBuilding"


func validate(state) -> bool:
	var problem := ProductionRules.build_problem(state, city_id, building_id, source_country)
	if problem != "":
		return _reject(problem)
	return true


func execute(state) -> CommandResult:
	var building := BuildingCatalog.get_building(building_id)
	var city: City = state.cities[city_id]
	var owner: Country = state.countries[(state.regions[city.region_id] as Region).country_id]
	owner.treasury = EconomyModel.next_treasury(owner.treasury, -building.cost)
	var order := ConstructionOrder.new()
	order.building_id = building_id
	order.seasons_total = building.build_seasons
	city.queue.append(order)
	state.city_changed.emit(city_id)
	return CommandResult.success({
		"city_id": city_id, "building_id": building_id,
		"cost": building.cost, "seasons": building.build_seasons})
