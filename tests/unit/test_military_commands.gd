extends "res://tests/test_base.gd"

const BusScript := preload("res://core/command_system/command_bus.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")
const ManagerScript := preload("res://core/game_time/season_tick_manager.gd")


func _init() -> void:
	print("test_military_commands")
	UnitCatalog.reset_cache()
	_test_recruit_success()
	_test_recruit_rejections()
	_test_recruit_exact_resources()
	_test_create_army()
	_test_create_army_rejections()
	_test_army_size_limit()
	_test_assign_general()
	_test_assign_general_rejections()
	_test_replace_general()
	_test_rules_agree_with_commands()
	_test_manpower_math()
	_test_manpower_grows_each_season()
	_test_save_and_load()
	_test_new_ids_continue_after_load()
	_test_corrupt_military_changes_nothing()
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


## Two cities of the first country (in different regions), the country and another country id.
func _setup(state: Node) -> Dictionary:
	var ids: Array = state.countries.keys()
	ids.sort()
	var country: Country = state.countries[ids[0]]
	var cities: Array[City] = []
	var city_ids: Array = state.cities.keys()
	city_ids.sort()
	for city_id in city_ids:
		var city: City = state.cities[city_id]
		if (state.regions[city.region_id] as Region).country_id == country.id:
			cities.append(city)
	return {"country": country, "city": cities[0], "city2": cities[1], "other": ids[1]}


func _recruit(ctx: Dictionary, city: City, type_id: String, country: Country) -> CommandResult:
	return ctx["bus"].submit(RecruitUnitCommand.new(city.id, type_id, country.id))


func _test_recruit_success() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var city: City = setup["city"]
	var changed := [0]
	state.military_changed.connect(func(): changed[0] += 1)
	var executed: Array = []
	ctx["events"].subscribe(Events.COMMAND_EXECUTED, func(p): executed.append(p))

	var result: CommandResult = _recruit(ctx, city, "infantry", country)
	check(result.ok, "recruiting infantry in an own city succeeds")
	check(country.treasury == 400.0, "100 gold were paid (500 -> %s)" % country.treasury)
	check(country.manpower == 4000.0, "1000 manpower were taken (5000 -> %s)" % country.manpower)
	check(state.units.size() == 1, "one unit exists")
	var unit: Unit = state.units["unit_00001"]
	check(unit.type_id == "infantry" and unit.country_id == country.id and unit.region_id == city.region_id, "the unit stands in the city's region")
	check(state.armies.is_empty(), "the unit is not in an army yet")
	check(changed[0] == 1, "military_changed is emitted once")
	check(executed.size() == 1 and executed[0]["data"]["unit_id"] == "unit_00001", "the executed event carries the unit id")
	check(WorldIntegrity.check(state).is_empty(), "the world stays consistent")
	check(_recruit(ctx, city, "cavalry", country).ok and state.units.has("unit_00002"), "the next unit gets the next id")
	_dispose(ctx)


func _test_recruit_rejections() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var city: City = setup["city"]
	var before: Dictionary = state.to_dict()
	var signals := [0]
	state.military_changed.connect(func(): signals[0] += 1)

	var r: CommandResult = ctx["bus"].submit(RecruitUnitCommand.new("city_99999", "infantry", country.id))
	check(not r.ok and "Unknown city" in r.reason, "unknown city rejected")
	r = ctx["bus"].submit(RecruitUnitCommand.new(city.id, "dragon", country.id))
	check(not r.ok and "Unknown unit type" in r.reason, "unknown unit type rejected")
	r = ctx["bus"].submit(RecruitUnitCommand.new(city.id, "infantry", setup["other"]))
	check(not r.ok and "not your city" in r.reason, "recruiting in a foreign city rejected")
	check(state.to_dict() == before and signals[0] == 0, "rejections change nothing and emit nothing")

	country.manpower = 999.0
	r = _recruit(ctx, city, "infantry", country)
	check(not r.ok and "Not enough manpower" in r.reason, "999 manpower is not enough for infantry (%s)" % r.reason)
	check(country.manpower == 999.0 and country.treasury == 500.0 and state.units.is_empty(), "a rejected order costs nothing")
	country.manpower = 5000.0
	country.treasury = 99.0
	r = _recruit(ctx, city, "infantry", country)
	check(not r.ok and "Not enough gold" in r.reason, "99 gold is not enough (%s)" % r.reason)
	(state.regions[city.region_id] as Region).country_id = ""
	r = ctx["bus"].submit(RecruitUnitCommand.new(city.id, "infantry", ""))
	check(not r.ok and "no owner" in r.reason, "a city of an ownerless region cannot recruit")
	_dispose(ctx)


func _test_recruit_exact_resources() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	country.manpower = 1000.0
	country.treasury = 100.0
	check(_recruit(ctx, setup["city"], "infantry", country).ok, "exactly enough manpower and gold is enough")
	check(country.manpower == 0.0 and country.treasury == 0.0, "both stocks are empty, not negative")
	check(ctx["bus"].submit(RecruitUnitCommand.new(setup["city"].id, "infantry")).ok == false, "a debug order still needs the resources")
	_dispose(ctx)


func _units(ctx: Dictionary, setup: Dictionary, count: int, type_id: String = "infantry") -> Array:
	var country: Country = setup["country"]
	country.manpower = 1.0e6
	country.treasury = 1.0e6
	var ids: Array = []
	for i in count:
		var result: CommandResult = _recruit(ctx, setup["city"], type_id, country)
		ids.append(result.data["unit_id"])
	return ids


func _test_create_army() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var city: City = setup["city"]
	var unit_ids := _units(ctx, setup, 3)
	var changed := [0]
	state.military_changed.connect(func(): changed[0] += 1)
	var result: CommandResult = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, unit_ids, "", country.id))
	check(result.ok, "forming an army from 3 free units succeeds")
	var army: Army = state.armies[result.data["army_id"]]
	check(army.id == "army_00001" and army.name == "Army 1", "the default name is Army N")
	check(army.country_id == country.id and army.region_id == city.region_id, "the army has the country and the position of its units")
	check(army.units == unit_ids and army.general_id == "", "the army holds the units and has no general")
	check(army.supply == 100.0 and army.order == "none", "placeholders have their defaults")
	check(MilitaryRules.free_units(state, country.id).is_empty(), "the units are not free any more")
	check(changed[0] == 1, "military_changed is emitted once")
	check(WorldIntegrity.check(state).is_empty(), "the world stays consistent")
	var more := _units(ctx, setup, 1, "cavalry")
	var named: CommandResult = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, more, "  Northern Host ", country.id))
	check(named.ok and (state.armies[named.data["army_id"]] as Army).name == "Northern Host", "a given name is used (trimmed)")
	_dispose(ctx)


func _test_create_army_rejections() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var city: City = setup["city"]
	var city2: City = setup["city2"]
	var here := _units(ctx, setup, 2)
	var far: Array = [_recruit(ctx, city2, "infantry", country).data["unit_id"]]
	var foreign_country: Country = state.countries[setup["other"]]
	var foreign_city: City = null
	for city_id in state.cities:
		if (state.regions[(state.cities[city_id] as City).region_id] as Region).country_id == foreign_country.id:
			foreign_city = state.cities[city_id]
			break
	var foreign: Array = [ctx["bus"].submit(RecruitUnitCommand.new(foreign_city.id, "infantry")).data["unit_id"]]
	var before: Dictionary = state.to_dict()
	var signals := [0]
	state.military_changed.connect(func(): signals[0] += 1)

	var r: CommandResult = ctx["bus"].submit(CreateArmyCommand.new("region_99999", here, "", country.id))
	check(not r.ok and "Unknown region" in r.reason, "unknown region rejected")
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, [], "", country.id))
	check(not r.ok and "at least one" in r.reason, "an empty choice rejected")
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, ["unit_99999"], "", country.id))
	check(not r.ok and "Unknown unit" in r.reason, "an unknown unit rejected")
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, [here[0], here[0]], "", country.id))
	check(not r.ok and "twice" in r.reason, "a unit listed twice rejected")
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, far, "", country.id))
	check(not r.ok and "is not in" in r.reason, "a unit from another region rejected")
	r = ctx["bus"].submit(CreateArmyCommand.new(foreign_city.region_id, foreign, "", country.id))
	check(not r.ok and "not your unit" in r.reason, "units of another country rejected")
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, here, "x".repeat(41), country.id))
	check(not r.ok and "too long" in r.reason, "a too long name rejected")
	check(state.to_dict() == before and signals[0] == 0, "rejections change nothing and emit nothing")

	check(ctx["bus"].submit(CreateArmyCommand.new(city.region_id, here, "", country.id)).ok, "the valid army is formed")
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, [here[0]], "", country.id))
	check(not r.ok and "already in an army" in r.reason, "a unit already in an army rejected")
	# debug source: units of two countries together
	var mixed: Array = [here[0]]
	r = ctx["bus"].submit(CreateArmyCommand.new(city.region_id, [far[0]], "", ""))
	check(not r.ok, "a debug order still needs units in the region")
	_dispose(ctx)


func _test_army_size_limit() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var region: String = (setup["city"] as City).region_id
	var ids := _units(ctx, setup, Army.MAX_UNITS + 1)
	var r: CommandResult = ctx["bus"].submit(CreateArmyCommand.new(region, ids, "", country.id))
	check(not r.ok and "at most" in r.reason, "21 units rejected: %s" % r.reason)
	var twenty := ids.slice(0, Army.MAX_UNITS)
	check(ctx["bus"].submit(CreateArmyCommand.new(region, twenty, "", country.id)).ok, "exactly 20 units accepted")
	check(MilitaryRules.free_units(state, country.id, region).size() == 1, "the 21st unit stays free")
	_dispose(ctx)


func _army_of(ctx: Dictionary, setup: Dictionary, count: int = 1) -> String:
	var ids := _units(ctx, setup, count)
	var country: Country = setup["country"]
	return ctx["bus"].submit(CreateArmyCommand.new((setup["city"] as City).region_id, ids, "", country.id)).data["army_id"]


func _test_assign_general() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var army_id := _army_of(ctx, setup)
	var free := MilitaryRules.free_generals(state, country.id)
	check(free.size() == GeneralFactory.PER_COUNTRY, "all four generals of the country are free")
	var changed := [0]
	state.military_changed.connect(func(): changed[0] += 1)
	var result: CommandResult = ctx["bus"].submit(AssignGeneralCommand.new(army_id, free[0], country.id))
	check(result.ok, "assigning a free general succeeds")
	check((state.armies[army_id] as Army).general_id == free[0] and (state.generals[free[0]] as General).army_id == army_id, "army and general point at each other")
	check(MilitaryRules.free_generals(state, country.id).size() == 3, "three generals are still free")
	check(changed[0] == 1, "military_changed is emitted once")
	check(WorldIntegrity.check(state).is_empty(), "the world stays consistent")
	_dispose(ctx)


func _test_assign_general_rejections() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var first := _army_of(ctx, setup)
	var second := _army_of(ctx, setup)
	var free := MilitaryRules.free_generals(state, country.id)
	ctx["bus"].submit(AssignGeneralCommand.new(first, free[0], country.id))
	var before: Dictionary = state.to_dict()
	var signals := [0]
	state.military_changed.connect(func(): signals[0] += 1)

	var r: CommandResult = ctx["bus"].submit(AssignGeneralCommand.new("army_99999", free[1], country.id))
	check(not r.ok and "Unknown army" in r.reason, "unknown army rejected")
	r = ctx["bus"].submit(AssignGeneralCommand.new(second, "general_99999", country.id))
	check(not r.ok and "Unknown general" in r.reason, "unknown general rejected")
	r = ctx["bus"].submit(AssignGeneralCommand.new(second, free[0], country.id))
	check(not r.ok and "already leads another army" in r.reason, "a general leads exactly one army")
	r = ctx["bus"].submit(AssignGeneralCommand.new(first, free[0], country.id))
	check(not r.ok and "already leads" in r.reason, "naming the same general again rejected")
	var foreign := MilitaryRules.free_generals(state, setup["other"])
	r = ctx["bus"].submit(AssignGeneralCommand.new(second, foreign[0], country.id))
	check(not r.ok and "serves another country" in r.reason, "a foreign general rejected")
	r = ctx["bus"].submit(AssignGeneralCommand.new(second, free[1], setup["other"]))
	check(not r.ok and "not your army" in r.reason, "naming a general of a foreign army rejected")
	check(state.to_dict() == before and signals[0] == 0, "rejections change nothing and emit nothing")
	_dispose(ctx)


func _test_replace_general() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var army_id := _army_of(ctx, setup)
	var free := MilitaryRules.free_generals(state, country.id)
	ctx["bus"].submit(AssignGeneralCommand.new(army_id, free[0], country.id))
	var result: CommandResult = ctx["bus"].submit(AssignGeneralCommand.new(army_id, free[1], country.id))
	check(result.ok and result.data["replaced_general"] == free[0], "a new general replaces the old one")
	check((state.generals[free[0]] as General).army_id == "" and (state.generals[free[1]] as General).army_id == army_id, "the old general is free, the new one leads")
	check(WorldIntegrity.check(state).is_empty(), "the world stays consistent")
	_dispose(ctx)


func _test_rules_agree_with_commands() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var setup := _setup(state)
	var country: Country = setup["country"]
	var city: City = setup["city"]
	check(MilitaryRules.recruit_problem(state, city.id, "infantry", country.id) == "", "no problem reported for a valid recruit")
	check(MilitaryRules.recruit_problem(state, city.id, "infantry", setup["other"]) != "", "a problem is reported for a foreign city")
	var ids := _units(ctx, setup, 2)
	check(MilitaryRules.army_problem(state, city.region_id, ids, country.id) == "", "no problem reported for a valid army")
	check(MilitaryRules.army_problem(state, city.region_id, [], country.id) != "", "a problem is reported for an empty army")
	var army_id := _army_of(ctx, setup)
	var general := MilitaryRules.free_generals(state, country.id)[0]
	check(MilitaryRules.general_problem(state, army_id, general, country.id) == "", "no problem reported for a valid general")
	check(MilitaryRules.general_problem(state, army_id, "general_99999", country.id) != "", "a problem is reported for an unknown general")
	check(MilitaryRules.free_units(state, country.id, city.region_id).size() == 2, "free_units lists the 2 units that are in no army")
	_dispose(ctx)


func _test_manpower_math() -> void:
	check(EconomyModel.next_manpower(100.0, 50.0) == 150.0, "positive change adds")
	check(EconomyModel.next_manpower(100.0, -30.0) == 70.0, "negative change subtracts")
	check(EconomyModel.next_manpower(10.0, -30.0) == 0.0, "the stock never goes below 0")
	check(EconomyModel.next_manpower(EconomyConfig.MANPOWER_LIMIT, 1.0e9) == EconomyConfig.MANPOWER_LIMIT, "the stock is capped")
	check(EconomyModel.next_manpower(100.0, NAN) == 100.0 and EconomyModel.next_manpower(100.0, INF) == 100.0, "a non-finite change is ignored")
	check(EconomyModel.next_manpower(NAN, 20.0) == 20.0, "a NaN stock is reset to 0 first")
	check(EconomyModel.next_manpower(0.0, 0.1 + 0.2) == 0.3, "the stock is rounded to cents")


func _test_manpower_grows_each_season() -> void:
	var manager = ManagerScript.new()
	var state = StateScript.new()
	WorldBuilder.start_new_game(state, 1)
	var events = EventBusScript.new()
	manager.state = state
	manager.event_bus = events
	manager.verbose = false
	GameSystems.register_all(manager)
	var country: Country = state.countries["country_00001"]
	var expected_gain := EconomyModel.country_report(country, state.regions, state.cities).get_output(ResourceTypes.Type.MANPOWER)
	check(expected_gain > 1000.0, "a country makes plenty of manpower per season (%.0f)" % expected_gain)
	manager.advance_season()
	check(country.manpower > EconomyConfig.STARTING_MANPOWER, "manpower grows in a season")
	check(absf(country.manpower - EconomyConfig.STARTING_MANPOWER - expected_gain) < expected_gain * 0.02, "by about one season of manpower output (the population grew a little first)")
	manager.free()
	events.free()
	state.free()


func _test_save_and_load() -> void:
	var ctx := _make()
	var a: Node = ctx["state"]
	var setup := _setup(a)
	var country: Country = setup["country"]
	var army_id := _army_of(ctx, setup, 3)
	ctx["bus"].submit(AssignGeneralCommand.new(army_id, MilitaryRules.free_generals(a, country.id)[0], country.id))
	_units(ctx, setup, 2, "cavalry")
	var b = StateScript.new()
	check(b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict()))) == OK, "a world with units, an army and a general loads through JSON")
	check(b.units.size() == a.units.size() and b.armies.size() == 1 and b.generals.size() == a.generals.size(), "everything is restored")
	check((b.armies[army_id] as Army).units == (a.armies[army_id] as Army).units, "the army keeps its units in order")
	check((b.armies[army_id] as Army).general_id == (a.armies[army_id] as Army).general_id, "the general is restored")
	check((b.countries[country.id] as Country).manpower == country.manpower, "the manpower stock is exactly the same")
	check(a.to_dict() == b.to_dict(), "the saved state is identical after the round trip")
	check(WorldIntegrity.check(b).is_empty(), "the loaded world is consistent")
	check(b.armies[army_id] != a.armies[army_id], "loaded armies are new objects")
	b.free()
	_dispose(ctx)


func _test_new_ids_continue_after_load() -> void:
	var ctx := _make()
	var a: Node = ctx["state"]
	var setup := _setup(a)
	var country: Country = setup["country"]
	_army_of(ctx, setup, 3)
	var b = StateScript.new()
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check(b.id_generator.next_id(IdTypes.Type.UNIT) == "unit_00004", "after loading, the next unit id is unit_00004")
	check(b.id_generator.next_id(IdTypes.Type.ARMY) == "army_00002", "after loading, the next army id is army_00002")
	b.free()
	_dispose(ctx)


func _test_corrupt_military_changes_nothing() -> void:
	var ctx := _make()
	var a: Node = ctx["state"]
	var setup := _setup(a)
	var country: Country = setup["country"]
	var army_id := _army_of(ctx, setup, 2)
	var good: Dictionary = a.to_dict()
	var target = StateScript.new()
	WorldBuilder.start_new_game(target, 7)
	target.game_date.advance()
	var before: Dictionary = target.to_dict()

	var ghost_unit := good.duplicate(true)
	ghost_unit["armies"][army_id]["units"].append("unit_00099")
	check(target.from_dict(ghost_unit) == ERR_INVALID_DATA, "an army with an unknown unit rejected")
	var wrong_key := good.duplicate(true)
	wrong_key["units"]["unit_00077"] = wrong_key["units"]["unit_00001"]
	check(target.from_dict(wrong_key) == ERR_INVALID_DATA, "a unit stored under another id rejected")
	var bad_type := good.duplicate(true)
	bad_type["units"]["unit_00001"]["type_id"] = "dragon"
	check(target.from_dict(bad_type) == ERR_INVALID_DATA, "a unit of an unknown type rejected")
	var one_way := good.duplicate(true)
	var general_id: String = good["generals"].keys()[0]
	one_way["armies"][army_id]["general_id"] = general_id
	check(target.from_dict(one_way) == ERR_INVALID_DATA, "a general link that is not mutual rejected")
	var no_armies := good.duplicate(true)
	no_armies.erase("generals")
	check(target.from_dict(no_armies) == ERR_INVALID_DATA, "a save without generals rejected")
	var bad_generals := good.duplicate(true)
	bad_generals["generals"][general_id]["attack"] = 500
	check(target.from_dict(bad_generals) == ERR_INVALID_DATA, "a malformed general rejected")
	check(target.to_dict() == before, "state untouched after every rejection")
	target.free()
	_dispose(ctx)
