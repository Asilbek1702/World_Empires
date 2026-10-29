extends "res://tests/test_base.gd"

const StateScript := preload("res://world/world_state.gd")
const RngScript := preload("res://core/rng/deterministic_rng.gd")


func _init() -> void:
	print("test_world_builder")
	var state = StateScript.new()
	var rng = RngScript.new()
	var emitted := [0]
	var regions_at_emit := [-1]
	state.state_replaced.connect(func():
		emitted[0] += 1
		regions_at_emit[0] = state.regions.size())

	var error := WorldBuilder.start_new_game(state, 4711, null, rng)
	check(error == OK, "start_new_game succeeds")
	check(state.regions.size() >= 150, "map regions are loaded into WorldState")
	check(state.rng_seed == 4711, "seed is set")
	check(rng.get_seed() == 4711, "GameRNG is seeded with the same seed")
	check(emitted[0] == 1, "state_replaced is emitted once")
	check(regions_at_emit[0] == state.regions.size(), "regions are already present when state_replaced fires")
	check(str(state.game_date) == "Spring 1000", "default start date")

	var first_id: String = state.regions.keys()[0]
	(state.regions[first_id] as Region).population = 5
	WorldBuilder.start_new_game(state, 1)
	check((state.regions[first_id] as Region).population == PopulationConfig.initial_population(state.regions[first_id]), "a new game starts with fresh regions (initial population)")

	var custom := GameDate.new(1914, GameDate.Season.SUMMER, 3)
	WorldBuilder.start_new_game(state, 1, custom)
	check(str(state.game_date) == "Summer 1914", "custom start date is used")
	check(state.countries.size() >= 4, "countries are loaded")
	check(WorldIntegrity.check(state).is_empty(), "a built world is fully consistent")
	check(state.get_player_country() == null, "no player country unless asked")
	var every_region_owned := true
	for id in state.regions:
		if (state.regions[id] as Region).country_id == "":
			every_region_owned = false
	check(every_region_owned, "every region has an owner")
	var everyone_lives_somewhere := true
	for id in state.regions:
		if (state.regions[id] as Region).population <= 0:
			everyone_lives_somewhere = false
	check(everyone_lives_somewhere, "every region starts with a population")
	check(state.cities.size() >= 40, "cities are loaded (%d)" % state.cities.size())
	var capitals_have_cities := true
	for cid in state.countries:
		var capital: Region = state.regions[(state.countries[cid] as Country).capital_region]
		if capital.cities.is_empty():
			capitals_have_cities = false
	check(capitals_have_cities, "every capital region has a city")
	var index_ok := true
	for cid in state.cities:
		var city: City = state.cities[cid]
		if not (state.regions[city.region_id] as Region).cities.has(cid):
			index_ok = false
	check(index_ok, "Region.cities lists every city")

	var chosen: String = state.countries.keys()[1]
	check(WorldBuilder.start_new_game(state, 3, null, null, chosen) == OK, "start with a chosen player country succeeds")
	check(state.get_player_country() != null and state.get_player_country().id == chosen, "the chosen country is the player")

	var seed_before: int = state.rng_seed
	check(WorldBuilder.start_new_game(state, 99, null, null, "country_99999") == ERR_INVALID_PARAMETER, "unknown player country is rejected")
	check(state.rng_seed == seed_before and state.get_player_country().id == chosen, "a rejected start changes nothing")
	state.free()
	rng.free()
	finish()
