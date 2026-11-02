class_name ResearchRules
extends RefCounted
## Who may start which research. One rule set, used by StartResearchCommand
## (to accept or reject) and by the research panel (to enable or disable buttons).


## Returns "" if the country may start the technology, otherwise the reason it cannot.
static func start_problem(state, country_id: String, technology_id: String) -> String:
	if not state.countries.has(country_id):
		return "Unknown country %s" % country_id
	var tech := TechnologyCatalog.get_technology(technology_id)
	if tech == null:
		return "Unknown technology %s" % technology_id
	var country: Country = state.countries[country_id]
	if country.researched_technologies.has(technology_id):
		return "%s is already researched" % tech.name
	if country.current_research == technology_id:
		return "%s is already being researched" % tech.name
	var missing := TechnologyModel.missing_requirements(country, tech)
	if not missing.is_empty():
		var names: Array[String] = []
		for required in missing:
			var other := TechnologyCatalog.get_technology(required)
			names.append(other.name if other != null else required)
		return "Requires: %s" % ", ".join(names)
	return ""
