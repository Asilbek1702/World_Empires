extends Node2D
## Bootstrap. Registers the game systems, starts a world so the map is visible on launch.
## The country select screen then asks the player to pick a country.


func _ready() -> void:
	print("WORLD EMPIRES — boot ok")
	GameSystems.register_all(SeasonTickManager)
	var error := WorldBuilder.start_new_game(WorldState, 0, null, GameRNG)
	if error != OK:
		push_error("Cannot start a new game: %s" % WorldBuilder.last_error)
		return
	print("[Map] %d regions, %d countries loaded" % [
		WorldState.regions.size(), WorldState.countries.size()])
	print("[Pop] world population: %s" % NumberFormat.thousands(PopulationStats.world_total(WorldState.regions)))
