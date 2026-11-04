class_name RecruitUnitCommand
extends Command
## Recruits one unit in a city. The owner of the city pays the gold and the manpower at once.
## The unit appears in the city's region, outside any army. All rules live in MilitaryRules.

var city_id: String = ""
var unit_type_id: String = ""


func _init(p_city_id: String = "", p_unit_type_id: String = "", p_source_country: String = "") -> void:
	city_id = p_city_id
	unit_type_id = p_unit_type_id
	source_country = p_source_country


func get_command_name() -> String:
	return "RecruitUnit"


func validate(state) -> bool:
	var problem := MilitaryRules.recruit_problem(state, city_id, unit_type_id, source_country)
	if problem != "":
		return _reject(problem)
	return true


func execute(state) -> CommandResult:
	var unit_type := UnitCatalog.get_unit_type(unit_type_id)
	var city: City = state.cities[city_id]
	var region: Region = state.regions[city.region_id]
	var owner: Country = state.countries[region.country_id]
	owner.treasury = EconomyModel.next_treasury(owner.treasury, -unit_type.cost)
	owner.manpower = EconomyModel.next_manpower(owner.manpower, -float(unit_type.manpower))
	var unit := Unit.new()
	unit.id = state.id_generator.next_id(IdTypes.Type.UNIT)
	unit.type_id = unit_type_id
	unit.country_id = owner.id
	unit.region_id = region.id
	state.units[unit.id] = unit
	state.military_changed.emit()
	return CommandResult.success({
		"unit_id": unit.id, "unit_type_id": unit_type_id, "region_id": region.id,
		"cost": unit_type.cost, "manpower": unit_type.manpower})
