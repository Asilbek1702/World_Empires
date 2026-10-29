class_name IGameSystem
extends RefCounted
## Base class for every game system (economy, military, diplomacy, ...).
## GDScript has no interfaces, so subclasses override the virtual methods.
## A system is stateless over the world: it reads and changes WorldState,
## which SeasonTickManager passes to on_season_tick().


func get_system_name() -> String:
	return "IGameSystem"


## Which step of the season this system runs in. MUST be overridden:
## SeasonTickManager refuses systems that do not name a valid TickOrder.Phase.
func get_tick_phase() -> int:
	return -1


## Called once per season, in phase order. `state` is the WorldState of the season
## that is ending (the date advances after the last phase).
func on_season_tick(_state) -> void:
	pass


## Called when a command targets this system.
func on_command(_cmd) -> Variant:
	return null
