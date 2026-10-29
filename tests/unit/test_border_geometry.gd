extends "res://tests/test_base.gd"


func _square(id: String, x: float, neighbors: Array) -> Region:
	return Region.from_static_dict({"id": id, "center": [x + 50, 50], "terrain": "plains",
			"polygon": [[x, 0], [x + 100, 0], [x + 100, 100], [x, 100]], "neighbors": neighbors})


func _row() -> Dictionary:
	var a := _square("region_00001", 0.0, ["region_00002"])
	var b := _square("region_00002", 100.0, ["region_00001", "region_00003"])
	var c := _square("region_00003", 200.0, ["region_00002"])
	return {a.id: a, b.id: b, c.id: c}


func _init() -> void:
	print("test_border_geometry")
	_test_pair_key()
	_test_two_squares()
	_test_split_by_owner()
	_test_real_map_edges()
	_test_real_map_borders_follow_owners()
	finish()


func _test_pair_key() -> void:
	check(BorderGeometry.pair_key("region_00002", "region_00001") == BorderGeometry.pair_key("region_00001", "region_00002"), "pair key ignores order")


func _test_two_squares() -> void:
	var a := _square("region_00001", 0.0, ["region_00002"])
	var b := _square("region_00002", 100.0, ["region_00001"])
	var g := BorderGeometry.build({a.id: a, b.id: b})
	var shared: Dictionary = g["shared"]
	check(shared.size() == 1 and shared.has("region_00001|region_00002"), "two squares share exactly one border")
	var seg: PackedVector2Array = shared["region_00001|region_00002"]
	check(seg.size() == 2, "the shared border is one segment")
	check(absf(seg[0].x - 100.0) < 0.01 and absf(seg[1].x - 100.0) < 0.01, "the shared segment lies on x = 100")
	check((g["coast"] as PackedVector2Array).size() == 12, "the other 6 edges are coast")


func _set_owners(regions: Dictionary, owners: Array) -> void:
	var i := 0
	for id in regions:
		(regions[id] as Region).country_id = owners[i]
		i += 1


func _test_split_by_owner() -> void:
	var regions := _row()
	var shared: Dictionary = BorderGeometry.build(regions)["shared"]
	_set_owners(regions, ["country_00001", "country_00001", "country_00002"])
	var split := BorderGeometry.split_by_owner(shared, regions, "")
	check((split["borders"] as PackedVector2Array).size() == 2, "only the edge between different owners is a border")
	check((split["player"] as PackedVector2Array).is_empty(), "no player borders without a player")

	var for_player := BorderGeometry.split_by_owner(shared, regions, "country_00002")
	check((for_player["player"] as PackedVector2Array).size() == 2 and (for_player["borders"] as PackedVector2Array).is_empty(), "a border touching the player goes to the player list")

	var other := BorderGeometry.split_by_owner(shared, regions, "country_00099")
	check((other["borders"] as PackedVector2Array).size() == 2 and (other["player"] as PackedVector2Array).is_empty(), "a border not touching the player stays a normal border")

	_set_owners(regions, ["country_00001", "country_00001", "country_00001"])
	var none := BorderGeometry.split_by_owner(shared, regions, "")
	check((none["borders"] as PackedVector2Array).is_empty(), "one owner everywhere means no borders")


func _test_real_map_edges() -> void:
	var regions := MapLoader.load_regions()
	var g := BorderGeometry.build(regions)
	var shared: Dictionary = g["shared"]
	var missing := 0
	for id in regions:
		for n in (regions[id] as Region).neighbors:
			var key := BorderGeometry.pair_key(id, n)
			if not shared.has(key) or (shared[key] as PackedVector2Array).size() < 2:
				missing += 1
	check(missing == 0, "every neighbor pair has a shared border (%d missing)" % missing)

	var total_edges := 0
	for id in regions:
		total_edges += (regions[id] as Region).polygon.size()
	var shared_edges := 0
	for key in shared:
		shared_edges += (shared[key] as PackedVector2Array).size() / 2
	var coast_edges := (g["coast"] as PackedVector2Array).size() / 2
	check(total_edges == 2 * shared_edges + coast_edges, "every polygon edge is shared or coast (%d = 2*%d + %d)" % [total_edges, shared_edges, coast_edges])


func _test_real_map_borders_follow_owners() -> void:
	var regions := MapLoader.load_regions()
	var shared: Dictionary = BorderGeometry.build(regions)["shared"]
	var countries := CountryLoader.load_countries()
	for cid in countries:
		for rid in (countries[cid] as Country).regions:
			(regions[rid] as Region).country_id = cid
	var ids: Array = countries.keys()
	ids.sort()
	var split := BorderGeometry.split_by_owner(shared, regions, ids[0])
	check(not (split["borders"] as PackedVector2Array).is_empty(), "the real world has borders between other countries")
	check(not (split["player"] as PackedVector2Array).is_empty(), "the real world has borders around the player")
	var before := (split["borders"] as PackedVector2Array).size() + (split["player"] as PackedVector2Array).size()

	# give everything to one country: all borders disappear
	for rid in regions:
		(regions[rid] as Region).country_id = ids[0]
	var after := BorderGeometry.split_by_owner(shared, regions, ids[0])
	check((after["borders"] as PackedVector2Array).is_empty() and (after["player"] as PackedVector2Array).is_empty(), "one owner for the whole map leaves no borders")
	check(before > 100, "the real world has plenty of border segments (%d points)" % before)
