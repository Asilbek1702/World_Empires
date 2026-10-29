class_name TickOrder
extends RefCounted
## The fixed order of one season (MVP Architecture Specification, section 6).
## A system declares its phase with IGameSystem.get_tick_phase().
## Phases run top to bottom; inside one phase systems run in registration order.
##
## Why this order (spec 3.62):
##   MOVEMENT -> BATTLES      armies must arrive before they can fight
##   BATTLES -> SUPPLY        supply is computed from the new positions and losses
##   SUPPLY -> PRODUCTION     production uses the supply state of this season
##   POPULATION -> ECONOMY    taxes and manpower depend on the new population
##   DIPLOMACY -> AI          AI decides on the already updated world
##   WORLD_UPDATE -> VICTORY_CHECK  rules are checked on the finished world
## After SAVE_CHECK the date advances and NEW_SEASON is published.
##
## Later iterations add phases (construction, trade, politics, events, intelligence)
## at their place in the spec 3.8 pipeline. Adding one is one line here.

enum Phase {
	VALIDATE_ACTIONS,  # queued player/AI actions are re-checked (spec step 1)
	MOVEMENT,
	BATTLES,
	SUPPLY,
	PRODUCTION,  # includes construction in the MVP
	POPULATION,
	ECONOMY,
	DIPLOMACY,
	AI,
	WORLD_UPDATE,  # borders, indexes, power scores
	VICTORY_CHECK,  # victory and defeat
	NOTIFICATIONS,
	SAVE_CHECK,  # autosave conditions
}


static func is_valid(phase: int) -> bool:
	return phase >= 0 and phase < Phase.size()


static func phase_name(phase: int) -> String:
	if not is_valid(phase):
		return "UNKNOWN(%d)" % phase
	return str(Phase.keys()[phase])
