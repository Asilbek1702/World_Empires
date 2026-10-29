extends "res://tests/test_base.gd"

const BusScript := preload("res://core/command_system/command_bus.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _init() -> void:
	print("test_build_command")
	BuildingCatalog.reset_cache()
	_test_successful_order()
	_test_two_orders_and_money()
	_test_rejections()
	_test_queue_limit()
	_test_not_enough_gold()
	_test_debug_source_may_build_anywhere()
	_test_ownerless_city()
	_test_rules_agree_with_command()
	BuildingCatalog.reset_cache()
	finish()


func _make() -> Dictionary:
	var ctx := {"bus": BusScript.new(), "state": StateScript.new(), "events": EventBusScript.new()}
	WorldBuilder.start_new_game(ctx["state"], 1)
	ctx["bus"].state = ctx["state"]
	ctx["bus"].event_bus = ctx["events"]
	ctx["bus"].verbose = false
	return ctx


func _dispose(ctx: Dictionary) -> void:
	for key in ctx:
		ctx[key].free()


## A non-capital city of the first country, and that country's id.
func _own_city(state: Node) -> Dictionary:
	var ids: Array = state.countries.keys()
	ids.sort()
	var country: Country = state.countries[ids[0]]
	for city_id in state.cities:
		var city: City = state.cities[city_id]
		if (state.regions[city.region_id] as Region).country_id == country.id and city.region_id != country.capital_region:
			return {"city": city, "country": country, "other": ids[1]}
	return {}


func _test_successful_order() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	var changed: Array = []
	state.city_changed.connect(func(id): changed.append(id))
	var executed: Array = []
	ctx["events"].subscribe(Events.COMMAND_EXECUTED, func(p): executed.append(p))

	var result: CommandResult = ctx["bus"].submit(BuildBuildingCommand.new(city.id, "farm", country.id))
	check(result.ok, "ordering a farm in an own city succeeds")
	check(country.treasury == 350.0, "150 gold were paid (500 -> %s)" % country.treasury)
	check(city.queue.size() == 1 and city.queue[0].building_id == "farm", "the farm is in the queue")
	check(city.queue[0].seasons_total == 3 and city.queue[0].seasons_done == 0, "3 seasons to build, none done")
	check(city.buildings.is_empty(), "nothing is built yet")
	check(changed == [city.id], "city_changed is emitted once")
	check(executed.size() == 1 and executed[0]["data"]["cost"] == 150.0, "the executed event carries the cost")
	check(WorldIntegrity.check(state).is_empty(), "the world stays consistent")
	_dispose(ctx)


func _test_two_orders_and_money() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	check(ctx["bus"].submit(BuildBuildingCommand.new(city.id, "farm", country.id)).ok, "first order")
	check(ctx["bus"].submit(BuildBuildingCommand.new(city.id, "market", country.id)).ok, "second order")
	check(country.treasury == 100.0, "500 - 150 - 250 = 100 left")
	check(city.queue.size() == 2 and city.queue[1].building_id == "market", "orders keep their order")
	_dispose(ctx)


func _test_rejections() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	var other_country: String = pick["other"]
	var before: Dictionary = state.to_dict()
	var signals: Array = []
	state.city_changed.connect(func(id): signals.append(id))

	var r: CommandResult = ctx["bus"].submit(BuildBuildingCommand.new("city_99999", "farm", country.id))
	check(not r.ok and "Unknown city" in r.reason, "unknown city rejected")
	r = ctx["bus"].submit(BuildBuildingCommand.new(city.id, "castle", country.id))
	check(not r.ok and "Unknown building" in r.reason, "unknown building rejected")
	r = ctx["bus"].submit(BuildBuildingCommand.new(city.id, "farm", other_country))
	check(not r.ok and "not your city" in r.reason, "building in a foreign city rejected")
	check(state.to_dict() == before and signals.is_empty(), "rejections change nothing and emit nothing")

	city.buildings.append("farm")
	r = ctx["bus"].submit(BuildBuildingCommand.new(city.id, "farm", country.id))
	check(not r.ok and "already has" in r.reason, "a second farm in the same city rejected")
	city.buildings.clear()

	check(ctx["bus"].submit(BuildBuildingCommand.new(city.id, "market", country.id)).ok, "market ordered")
	r = ctx["bus"].submit(BuildBuildingCommand.new(city.id, "market", country.id))
	check(not r.ok and "already being built" in r.reason, "the same building twice in the queue rejected")
	_dispose(ctx)


func _test_queue_limit() -> void:
	var extra := {}
	for id in ["farm", "market", "factory", "mill"]:
		extra[id] = Building.from_dict({"id": id, "name": id.capitalize(), "cost": 10,
				"build_seasons": 2, "output_modifiers": {"food": 0.1}})
	BuildingCatalog.override_for_tests(extra)
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	var accepted := 0
	var last: CommandResult = null
	for id in ["farm", "market", "factory", "mill"]:
		last = ctx["bus"].submit(BuildBuildingCommand.new(city.id, id, country.id))
		if last.ok:
			accepted += 1
	check(accepted == ProductionRules.MAX_QUEUE_SIZE, "the queue takes %d orders" % ProductionRules.MAX_QUEUE_SIZE)
	check(not last.ok and "queue" in last.reason, "the next order is rejected: %s" % last.reason)
	check(country.treasury == 500.0 - 30.0, "a rejected order costs nothing")
	_dispose(ctx)
	BuildingCatalog.reset_cache()


func _test_not_enough_gold() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	country.treasury = 100.0
	var r: CommandResult = ctx["bus"].submit(BuildBuildingCommand.new(city.id, "market", country.id))
	check(not r.ok and "Not enough gold" in r.reason, "a poor country cannot build (%s)" % r.reason)
	check(country.treasury == 100.0 and city.queue.is_empty(), "nothing was paid and nothing queued")
	country.treasury = 250.0
	check(ctx["bus"].submit(BuildBuildingCommand.new(city.id, "market", country.id)).ok, "exactly enough gold is enough")
	check(country.treasury == 0.0, "the treasury is empty, not negative")
	_dispose(ctx)


func _test_debug_source_may_build_anywhere() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	check(ctx["bus"].submit(BuildBuildingCommand.new(city.id, "farm")).ok, "source '' (debug) may order in any city")
	check(country.treasury == 350.0, "the OWNER of the city pays")
	_dispose(ctx)


func _test_ownerless_city() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	(state.regions[city.region_id] as Region).country_id = ""
	var problem := ProductionRules.build_problem(state, city.id, "farm", "")
	check("no owner" in problem, "a city of an ownerless region cannot build (%s)" % problem)
	_dispose(ctx)


func _test_rules_agree_with_command() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _own_city(state)
	var city: City = pick["city"]
	var country: Country = pick["country"]
	check(ProductionRules.build_problem(state, city.id, "farm", country.id) == "", "no problem reported for a valid order")
	check(ProductionRules.build_problem(state, city.id, "farm", pick["other"]) != "", "a problem is reported for a foreign city")
	check(ProductionRules.build_problem(state, "city_99999", "farm", "") != "", "a problem is reported for an unknown city")
	_dispose(ctx)
