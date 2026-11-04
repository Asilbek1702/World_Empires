class_name EconomyModel
extends RefCounted
## The economy formulas as pure functions (no state, easy to test).
##
##   region output  = population * per-person rate   (food also * terrain fertility)
##   country output = sum over the regions it owns
##   (region output is multiplied by 1 + the bonuses of the buildings in its cities)
##   expenses       = administration: regions owned * ADMIN_COST_PER_REGION
##   net gold       = gold income - expenses
##   treasury(next) = clamp(treasury + net gold, 0, TREASURY_LIMIT), rounded to cents
##
## WHY CENTS: Godot's JSON writes a float with ~15 significant digits, so an arbitrary
## float (0.1 + 0.2) does not survive save and load bit for bit, and a loaded game
## would drift away from the original. A value of the form round(x * 100) / 100 is
## written and read back EXACTLY. Every saved float must follow this rule.
##
## Regions are summed in Country.regions order (sorted), so the result is reproducible.


## ResourceTypes.Type (int) -> float produced this season by one region.
## bonuses: ResourceTypes.Type -> summed building modifier (see ProductionModel).
## Output = base * (1 + bonus), never below 0.
static func region_output(region: Region, bonuses: Dictionary = {}) -> Dictionary:
	var people := float(maxi(region.population, 0))
	var fertility: float = EconomyConfig.FERTILITY[region.terrain]
	var base := {
		ResourceTypes.Type.GOLD: people * EconomyConfig.GOLD_PER_PERSON,
		ResourceTypes.Type.FOOD: people * EconomyConfig.FOOD_PER_PERSON * fertility,
		ResourceTypes.Type.INDUSTRY: people * EconomyConfig.INDUSTRY_PER_PERSON,
		ResourceTypes.Type.SCIENCE: people * EconomyConfig.SCIENCE_PER_PERSON,
		ResourceTypes.Type.MANPOWER: people * EconomyConfig.MANPOWER_PER_PERSON,
	}
	if bonuses.is_empty():
		return base
	var out := {}
	for type in base:
		out[type] = base[type] * maxf(1.0 + float(bonuses.get(type, 0.0)), 0.0)
	return out


## What one more building of this type would add per season in this region
## (ResourceTypes.Type -> float), without the bonuses already present.
static func building_gain(region: Region, building: Building) -> Dictionary:
	var base := region_output(region)
	var gain := {}
	for type in building.output_modifiers:
		gain[type] = float(base[type]) * float(building.output_modifiers[type])
	return gain


static func admin_cost(country: Country) -> float:
	return float(country.regions.size()) * EconomyConfig.ADMIN_COST_PER_REGION


static func country_report(country: Country, regions: Dictionary, cities: Dictionary = {}) -> EconomyReport:
	var report := EconomyReport.new()
	for type in ResourceTypes.Type.values():
		report.output[type] = 0.0
	var tech_bonuses := TechnologyModel.country_bonuses(country)
	for region_id in country.regions:
		if not regions.has(region_id):
			continue
		var region: Region = regions[region_id]
		var bonuses := tech_bonuses.duplicate()
		if not cities.is_empty():
			var local := ProductionModel.region_bonuses(region, cities)
			for type in local:
				bonuses[type] = float(bonuses.get(type, 0.0)) + float(local[type])
		var produced := region_output(region, bonuses)
		for type in produced:
			report.output[type] += produced[type]
	report.expense_items["Administration"] = admin_cost(country)
	return report


## The treasury never goes below 0 (no debt in the MVP) or above TREASURY_LIMIT,
## non-finite numbers (NaN, infinity) are ignored, and the result is in whole cents.
static func next_treasury(treasury: float, net: float) -> float:
	var base := treasury if is_finite(treasury) else 0.0
	var change := net if is_finite(net) else 0.0
	return round_money(clampf(base + change, 0.0, EconomyConfig.TREASURY_LIMIT))


## The manpower stock never goes below 0 or above MANPOWER_LIMIT, non-finite numbers are
## ignored, and the result is in whole cents (same rule as the treasury).
static func next_manpower(stock: float, change: float) -> float:
	var base := stock if is_finite(stock) else 0.0
	var delta := change if is_finite(change) else 0.0
	return round_money(clampf(base + delta, 0.0, EconomyConfig.MANPOWER_LIMIT))


## Rounds to whole cents in a form that JSON stores exactly (see the note above).
static func round_money(amount: float) -> float:
	return roundf(amount * 100.0) / 100.0
