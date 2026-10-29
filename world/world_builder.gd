class_name WorldBuilder
extends RefCounted
## Builds a ready-to-play world: static map + starting countries + fresh dynamic state.
## Later iterations extend this (cities, armies, ...).

static var last_error: String = ""


## rng (optional): seeded with p_seed so WorldState and GameRNG always agree.
## player_country_id (optional): "" = nobody yet (the country select screen asks).
## Nothing is changed unless every step succeeds.
static func start_new_game(state: Node, p_seed: int, start_date: GameDate = null,
		rng: Node = null, player_country_id: String = "") -> Error:
	last_error = ""
	var regions := MapLoader.load_regions()
	if regions.is_empty():
		last_error = MapLoader.last_error
		return ERR_FILE_NOT_FOUND
	var countries := CountryLoader.load_countries()
	if countries.is_empty():
		last_error = CountryLoader.last_error
		return ERR_FILE_NOT_FOUND
	var cities := CityLoader.load_cities()
	if cities.is_empty():
		last_error = CityLoader.last_error
		return ERR_FILE_NOT_FOUND
	var problems := CountryLoader.validate_against_map(countries, regions)
	problems.append_array(CityLoader.validate_against_map(cities, regions, countries))
	if not problems.is_empty():
		last_error = "; ".join(problems.slice(0, 5))
		return ERR_INVALID_DATA
	if player_country_id != "" and not countries.has(player_country_id):
		last_error = "Unknown player country %s" % player_country_id
		return ERR_INVALID_PARAMETER

	for cid in countries:
		for rid in (countries[cid] as Country).regions:
			(regions[rid] as Region).country_id = cid
	for rid in regions:
		(regions[rid] as Region).population = PopulationConfig.initial_population(regions[rid])
	for cid in countries:
		(countries[cid] as Country).treasury = EconomyConfig.STARTING_TREASURY
	if player_country_id != "":
		(countries[player_country_id] as Country).is_player_controlled = true

	if rng != null:
		rng.set_seed(p_seed)
	state.new_game(p_seed, start_date, regions, countries, cities)
	return OK
