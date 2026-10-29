extends "res://tests/test_base.gd"

const BusScript := preload("res://core/command_system/command_bus.gd")
const StateScript := preload("res://world/world_state.gd")
const EventBusScript := preload("res://core/event_bus/event_bus.gd")


func _init() -> void:
	print("test_territory_commands")
	_test_transfer_success()
	_test_transfer_rejections()
	_test_many_transfers_stay_consistent()
	_test_low_level_set_region_owner()
	_test_select_player_country()
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


## A non-capital region of the first country, and the id of a different country.
func _pick(state: Node) -> Dictionary:
	var ids: Array = state.countries.keys()
	ids.sort()
	var from_country: Country = state.countries[ids[0]]
	var region_id := ""
	for rid in from_country.regions:
		if rid != from_country.capital_region:
			region_id = rid
			break
	return {"region": region_id, "from": ids[0], "to": ids[1]}


func _test_transfer_success() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _pick(state)
	var signals: Array = []
	state.region_owner_changed.connect(func(r, o, n): signals.append([r, o, n]))
	var executed: Array = []
	ctx["events"].subscribe(Events.COMMAND_EXECUTED, func(p): executed.append(p))

	var result: CommandResult = ctx["bus"].submit(TransferRegionCommand.new(pick["region"], pick["to"]))
	check(result.ok, "transfer succeeds")
	check((state.regions[pick["region"]] as Region).country_id == pick["to"], "region has the new owner")
	check(not (state.countries[pick["from"]] as Country).regions.has(pick["region"]), "old owner lost the region from its list")
	check((state.countries[pick["to"]] as Country).regions.has(pick["region"]), "new owner has the region in its list")
	var list: Array = (state.countries[pick["to"]] as Country).regions
	var sorted_list := list.duplicate()
	sorted_list.sort()
	check(list == sorted_list, "new owner's region list stays sorted")
	check(WorldIntegrity.check(state).is_empty(), "world is still consistent")
	check(signals == [[pick["region"], pick["from"], pick["to"]]], "region_owner_changed emitted once with old and new owner")
	check(executed.size() == 1 and executed[0]["data"]["old_owner"] == pick["from"], "executed event carries the old owner")
	_dispose(ctx)


func _test_transfer_rejections() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _pick(state)
	var before: Dictionary = state.to_dict()
	var signals: Array = []
	state.region_owner_changed.connect(func(_r, _o, _n): signals.append(1))

	var r1: CommandResult = ctx["bus"].submit(TransferRegionCommand.new("region_99999", pick["to"]))
	check(not r1.ok and "Unknown region" in r1.reason, "unknown region rejected")
	var r2: CommandResult = ctx["bus"].submit(TransferRegionCommand.new(pick["region"], "country_99999"))
	check(not r2.ok and "Unknown country" in r2.reason, "unknown country rejected")
	var r3: CommandResult = ctx["bus"].submit(TransferRegionCommand.new(pick["region"], pick["from"]))
	check(not r3.ok and "already belongs" in r3.reason, "transfer to the current owner rejected")
	var capital: String = (state.countries[pick["from"]] as Country).capital_region
	var r4: CommandResult = ctx["bus"].submit(TransferRegionCommand.new(capital, pick["to"]))
	check(not r4.ok and "capital" in r4.reason, "transferring a capital is rejected")
	check(state.to_dict() == before, "rejected transfers change nothing")
	check(signals.is_empty(), "rejected transfers emit no signal")
	_dispose(ctx)


func _test_many_transfers_stay_consistent() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var ids: Array = state.countries.keys()
	ids.sort()
	var accepted := 0
	var region_ids: Array = state.regions.keys()
	for i in 60:
		var rid: String = region_ids[(i * 7) % region_ids.size()]
		var target: String = ids[i % ids.size()]
		if ctx["bus"].submit(TransferRegionCommand.new(rid, target)).ok:
			accepted += 1
	check(accepted > 20, "many transfers were accepted (%d)" % accepted)
	var problems: Array[String] = WorldIntegrity.check(state)
	check(problems.is_empty(), "world is consistent after many transfers %s" % str(problems.slice(0, 3)))
	_dispose(ctx)


func _test_low_level_set_region_owner() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var pick := _pick(state)
	var signals: Array = []
	state.region_owner_changed.connect(func(_r, _o, _n): signals.append(1))
	check(state.set_region_owner("region_99999", pick["to"]) == ERR_DOES_NOT_EXIST, "unknown region -> ERR_DOES_NOT_EXIST")
	check(state.set_region_owner(pick["region"], "country_99999") == ERR_DOES_NOT_EXIST, "unknown country -> ERR_DOES_NOT_EXIST")
	check(state.set_region_owner(pick["region"], pick["from"]) == OK, "setting the same owner is OK")
	check(signals.is_empty(), "setting the same owner emits nothing")
	_dispose(ctx)


func _test_select_player_country() -> void:
	var ctx := _make()
	var state: Node = ctx["state"]
	var ids: Array = state.countries.keys()
	ids.sort()
	var changed: Array = []
	state.player_country_changed.connect(func(id): changed.append(id))
	check(state.get_player_country() == null, "nobody is the player at the start")

	var bad: CommandResult = ctx["bus"].submit(SelectPlayerCountryCommand.new("country_99999"))
	check(not bad.ok and "Unknown country" in bad.reason, "unknown country rejected")
	check(state.get_player_country() == null and changed.is_empty(), "rejection changes nothing")

	var good: CommandResult = ctx["bus"].submit(SelectPlayerCountryCommand.new(ids[2]))
	check(good.ok, "selecting a country succeeds")
	check(state.get_player_country() != null and state.get_player_country().id == ids[2], "get_player_country returns it")
	var flags := 0
	for id in ids:
		if (state.countries[id] as Country).is_player_controlled:
			flags += 1
	check(flags == 1, "exactly one country is marked as the player")
	check(changed == [ids[2]], "player_country_changed emitted once")

	var again: CommandResult = ctx["bus"].submit(SelectPlayerCountryCommand.new(ids[0]))
	check(not again.ok and "already selected" in again.reason, "the player cannot switch countries")
	check(state.get_player_country().id == ids[2], "the first choice stays")
	_dispose(ctx)
