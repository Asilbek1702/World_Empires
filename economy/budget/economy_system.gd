class_name EconomySystem
extends IGameSystem
## Pays every country its net gold once per season (phase ECONOMY).
## Runs after POPULATION, so income uses this season's new population.
## Iter 9: gold income from population, administration expense. No trade, no buildings.


func get_system_name() -> String:
	return "Economy"


func get_tick_phase() -> int:
	return TickOrder.Phase.ECONOMY


func on_season_tick(state) -> void:
	for id in state.countries:
		var country: Country = state.countries[id]
		var report := EconomyModel.country_report(country, state.regions, state.cities)
		country.treasury = EconomyModel.next_treasury(country.treasury, report.net_gold())
