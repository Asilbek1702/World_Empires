class_name AssignGeneralCommand
extends Command
## Puts a free general at the head of an army. A general leads exactly one army.
## If the army already has a general, that one becomes free. Rules: MilitaryRules.

var army_id: String = ""
var general_id: String = ""


func _init(p_army_id: String = "", p_general_id: String = "", p_source_country: String = "") -> void:
	army_id = p_army_id
	general_id = p_general_id
	source_country = p_source_country


func get_command_name() -> String:
	return "AssignGeneral"


func validate(state) -> bool:
	var problem := MilitaryRules.general_problem(state, army_id, general_id, source_country)
	if problem != "":
		return _reject(problem)
	return true


func execute(state) -> CommandResult:
	var army: Army = state.armies[army_id]
	var replaced := army.general_id
	if replaced != "" and state.generals.has(replaced):
		(state.generals[replaced] as General).army_id = ""
	army.general_id = general_id
	(state.generals[general_id] as General).army_id = army_id
	state.military_changed.emit()
	return CommandResult.success({
		"army_id": army_id, "general_id": general_id, "replaced_general": replaced})
