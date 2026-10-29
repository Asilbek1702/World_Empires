class_name ProductionSystem
extends IGameSystem
## Moves construction forward once per season (phase PRODUCTION).
## Runs before ECONOMY, so a building finished this season already counts in this
## season's economy. Completion emits WorldState.building_completed exactly once.
## Iter 10: time-based construction. Industry does not speed it up yet.


func get_system_name() -> String:
	return "Production"


func get_tick_phase() -> int:
	return TickOrder.Phase.PRODUCTION


func on_season_tick(state) -> void:
	for city_id in state.cities:
		var city: City = state.cities[city_id]
		var finished := city.advance_construction()
		if finished != "":
			state.city_changed.emit(city_id)
			state.building_completed.emit(city_id, finished)
