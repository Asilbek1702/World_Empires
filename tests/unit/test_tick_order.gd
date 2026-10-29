extends "res://tests/test_base.gd"
## The pipeline order is a contract (MVP Architecture Specification, section 6).


func _init() -> void:
	print("test_tick_order")
	_test_exact_order()
	_test_dependencies()
	_test_helpers()
	finish()


func _names() -> Array:
	var out: Array = []
	for phase in TickOrder.Phase.size():
		out.append(TickOrder.phase_name(phase))
	return out


func _test_exact_order() -> void:
	check(_names() == [
			"VALIDATE_ACTIONS", "MOVEMENT", "BATTLES", "SUPPLY", "PRODUCTION", "POPULATION",
			"ECONOMY", "DIPLOMACY", "AI", "WORLD_UPDATE", "VICTORY_CHECK", "NOTIFICATIONS",
			"SAVE_CHECK"], "the 13 phases are in the order of the specification")


func _test_dependencies() -> void:
	var P := TickOrder.Phase
	check(P.VALIDATE_ACTIONS == 0, "validation runs first")
	check(P.MOVEMENT < P.BATTLES, "movement before battles")
	check(P.BATTLES < P.SUPPLY, "battles before supply")
	check(P.SUPPLY < P.PRODUCTION, "supply before production")
	check(P.POPULATION < P.ECONOMY, "population before economy (taxes, manpower)")
	check(P.ECONOMY < P.AI and P.DIPLOMACY < P.AI, "AI decides after economy and diplomacy are updated")
	check(P.AI < P.WORLD_UPDATE, "AI acts before the world state is finalized")
	check(P.WORLD_UPDATE < P.VICTORY_CHECK, "victory is checked on the finished world")
	check(P.VICTORY_CHECK < P.NOTIFICATIONS, "notifications come after the victory check")
	check(P.SAVE_CHECK == TickOrder.Phase.size() - 1, "save check runs last")


func _test_helpers() -> void:
	check(TickOrder.is_valid(0) and TickOrder.is_valid(TickOrder.Phase.size() - 1), "first and last phase are valid")
	check(not TickOrder.is_valid(-1) and not TickOrder.is_valid(TickOrder.Phase.size()), "out of range phases are invalid")
	check(TickOrder.phase_name(99) == "UNKNOWN(99)", "unknown phase has a readable name")
