class_name StartResearchCommand
extends Command
## Chooses the technology a country researches. The country is source_country.
## Changing the research drops the progress of the previous one. All rules live in ResearchRules.

var technology_id: String = ""


func _init(p_technology_id: String = "", p_country_id: String = "") -> void:
	technology_id = p_technology_id
	source_country = p_country_id


func get_command_name() -> String:
	return "StartResearch"


func validate(state) -> bool:
	var problem := ResearchRules.start_problem(state, source_country, technology_id)
	if problem != "":
		return _reject(problem)
	return true


func execute(state) -> CommandResult:
	var country: Country = state.countries[source_country]
	var lost := country.research_progress if country.current_research != "" else 0.0
	var dropped := country.current_research
	country.current_research = technology_id
	country.research_progress = 0.0
	state.research_changed.emit(source_country)
	return CommandResult.success({
		"country_id": source_country, "technology_id": technology_id,
		"dropped_technology": dropped, "lost_progress": lost})
