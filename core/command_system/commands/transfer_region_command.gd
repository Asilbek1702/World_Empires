class_name TransferRegionCommand
extends Command
## Gives a region to another country. Borders follow automatically.
## Iter 6 rule: a capital cannot be transferred. Capital relocation arrives with
## conquest (Iter 15) and will relax this check.

var region_id: String = ""
var new_owner_id: String = ""


func _init(p_region_id: String = "", p_new_owner_id: String = "", p_source_country: String = "") -> void:
	region_id = p_region_id
	new_owner_id = p_new_owner_id
	source_country = p_source_country


func get_command_name() -> String:
	return "TransferRegion"


func validate(state) -> bool:
	if not state.regions.has(region_id):
		return _reject("Unknown region %s" % region_id)
	if not state.countries.has(new_owner_id):
		return _reject("Unknown country %s" % new_owner_id)
	var region: Region = state.regions[region_id]
	if region.country_id == new_owner_id:
		return _reject("%s already belongs to %s" % [region_id, new_owner_id])
	var old_owner = state.countries.get(region.country_id)
	if old_owner != null and (old_owner as Country).capital_region == region_id:
		return _reject("Cannot transfer a capital (capital relocation is not implemented yet)")
	return true


func execute(state) -> CommandResult:
	var old_owner: String = (state.regions[region_id] as Region).country_id
	var error: Error = state.set_region_owner(region_id, new_owner_id)
	if error != OK:
		return CommandResult.failure("Transfer failed: %s" % error_string(error))
	return CommandResult.success({
		"region_id": region_id, "old_owner": old_owner, "new_owner": new_owner_id})
