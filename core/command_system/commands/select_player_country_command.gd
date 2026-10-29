class_name SelectPlayerCountryCommand
extends Command
## Chooses which country the player controls. Allowed once per campaign:
## the player cannot switch countries later (spec 1.25).

var country_id: String = ""


func _init(p_country_id: String = "") -> void:
	country_id = p_country_id


func get_command_name() -> String:
	return "SelectPlayerCountry"


func validate(state) -> bool:
	if not state.countries.has(country_id):
		return _reject("Unknown country %s" % country_id)
	if state.get_player_country() != null:
		return _reject("A player country is already selected")
	return true


func execute(state) -> CommandResult:
	var error: Error = state.set_player_country(country_id)
	if error != OK:
		return CommandResult.failure("Cannot select country: %s" % error_string(error))
	return CommandResult.success({"country_id": country_id})
