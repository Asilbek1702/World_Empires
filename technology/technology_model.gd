class_name TechnologyModel
extends RefCounted
## What technologies do (pure functions, no state).
##
##   country bonus of a resource = sum of that resource's modifiers over the
##                                 technologies the country has researched
##   output = base output * (1 + building bonus + country bonus)
##            (see EconomyModel.country_report)
##   progress(next) = progress + science of the season, whole cents


## ResourceTypes.Type (int) -> summed modifier of the researched technologies.
static func country_bonuses(country: Country, catalog: Dictionary = TechnologyCatalog.get_all()) -> Dictionary:
	var bonuses := {}
	for tech_id in country.researched_technologies:
		var tech: Technology = catalog.get(tech_id)
		if tech == null:
			continue
		for type in tech.output_modifiers:
			bonuses[type] = float(bonuses.get(type, 0.0)) + float(tech.output_modifiers[type])
	return bonuses


## Required technologies the country has not researched yet.
static func missing_requirements(country: Country, tech: Technology) -> Array[String]:
	var missing: Array[String] = []
	for required in tech.requires:
		if not country.researched_technologies.has(required):
			missing.append(required)
	return missing


## Ids (sorted) the country may start now: not researched, all requirements met.
static func available(country: Country, catalog: Dictionary = TechnologyCatalog.get_all()) -> Array[String]:
	var out: Array[String] = []
	var ids: Array = catalog.keys()
	ids.sort()
	for id in ids:
		var tech: Technology = catalog[id]
		if not country.researched_technologies.has(id) and missing_requirements(country, tech).is_empty():
			out.append(id as String)
	return out


## Progress after one more season. Never below 0, non-finite science is ignored.
static func next_progress(progress: float, science: float) -> float:
	var gained := science if is_finite(science) else 0.0
	return EconomyModel.round_money(maxf(progress, 0.0) + maxf(gained, 0.0))


## Whole seasons still needed at this science rate. -1 = no science, never finishes.
static func seasons_left(progress: float, cost: int, science: float) -> int:
	if not is_finite(science) or science <= 0.0:
		return -1
	var remaining := float(cost) - progress
	if remaining <= 0.0:
		return 0
	return int(ceil(remaining / science))
