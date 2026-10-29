class_name PopulationSystem
extends IGameSystem
## Grows the population of every region once per season (phase POPULATION).
## Runs before ECONOMY, so taxes and manpower see the new population.
## Iter 8: growth only. Migration, age groups and war losses come later.


func get_system_name() -> String:
	return "Population"


func get_tick_phase() -> int:
	return TickOrder.Phase.POPULATION


func on_season_tick(state) -> void:
	for id in state.regions:
		var region: Region = state.regions[id]
		region.population = PopulationModel.next_population(
			region.population, PopulationConfig.capacity(region))
