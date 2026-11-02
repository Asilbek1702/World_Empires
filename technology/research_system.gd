class_name ResearchSystem
extends IGameSystem
## Moves research forward once per season (phase WORLD_UPDATE).
## Runs after ECONOMY, so it spends this season's science, bonuses included.
## A technology finished now boosts the economy from the NEXT season.
## Iter 11 rules:
##   - a country researches one technology at a time (StartResearchCommand)
##   - without a chosen technology its science is wasted
##   - science left over after completion is lost
##   - AI countries do not choose research yet (Iter 16)


func get_system_name() -> String:
	return "Research"


func get_tick_phase() -> int:
	return TickOrder.Phase.WORLD_UPDATE


func on_season_tick(state) -> void:
	var ids: Array = state.countries.keys()
	ids.sort()
	for id in ids:
		var country: Country = state.countries[id]
		if country.current_research == "":
			continue
		var tech := TechnologyCatalog.get_technology(country.current_research)
		if tech == null:
			country.current_research = ""
			country.research_progress = 0.0
			state.research_changed.emit(id)
			continue
		var report := EconomyModel.country_report(country, state.regions, state.cities)
		var progress := TechnologyModel.next_progress(
			country.research_progress, report.get_output(ResourceTypes.Type.SCIENCE))
		if progress >= float(tech.cost):
			country.researched_technologies.append(tech.id)
			country.current_research = ""
			country.research_progress = 0.0
			state.research_changed.emit(id)
			state.technology_researched.emit(id, tech.id)
		else:
			country.research_progress = progress
			state.research_changed.emit(id)
