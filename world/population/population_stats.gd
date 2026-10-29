class_name PopulationStats
extends RefCounted
## Read-only totals. Spec 5.2: a country's population is the sum of its regions.


static func country_total(country: Country, regions: Dictionary) -> int:
	var total := 0
	for region_id in country.regions:
		if regions.has(region_id):
			total += (regions[region_id] as Region).population
	return total


static func world_total(regions: Dictionary) -> int:
	var total := 0
	for id in regions:
		total += (regions[id] as Region).population
	return total
