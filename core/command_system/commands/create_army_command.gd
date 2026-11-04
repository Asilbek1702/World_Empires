class_name CreateArmyCommand
extends Command
## Forms an army from free units standing in one region. The army belongs to the
## country of its units and starts without a general. An empty name gives "Army N".
## All rules live in MilitaryRules.

var region_id: String = ""
var unit_ids: Array = []
var army_name: String = ""


func _init(p_region_id: String = "", p_unit_ids: Array = [], p_army_name: String = "",
		p_source_country: String = "") -> void:
	region_id = p_region_id
	unit_ids = p_unit_ids
	army_name = p_army_name
	source_country = p_source_country


func get_command_name() -> String:
	return "CreateArmy"


func validate(state) -> bool:
	var problem := MilitaryRules.army_problem(state, region_id, unit_ids, source_country)
	if problem != "":
		return _reject(problem)
	if army_name.strip_edges() != "" and not Army.valid_name(army_name):
		return _reject("The army name is too long (max %d characters)" % Army.MAX_NAME_LENGTH)
	return true


func execute(state) -> CommandResult:
	var army := Army.new()
	army.id = state.id_generator.next_id(IdTypes.Type.ARMY)
	army.name = army_name.strip_edges()
	if army.name == "":
		army.name = "Army %d" % IdTypes.number_of(army.id)
	army.country_id = (state.units[unit_ids[0]] as Unit).country_id
	army.region_id = region_id
	for unit_id in unit_ids:
		army.units.append(unit_id)
	state.armies[army.id] = army
	state.military_changed.emit()
	return CommandResult.success({
		"army_id": army.id, "name": army.name, "region_id": region_id, "units": army.units.size()})
