class_name BorderGeometry
extends RefCounted
## Finds the polygon edges shared by two regions (borders) and the edges that
## belong to one region only (coast). Pure geometry of the static map.
##
## build() returns:
##   "shared": Dictionary  "<idA>|<idB>" (A < B) -> PackedVector2Array of segment endpoints
##             (p0, q0, p1, q1, ...) ready for draw_multiline()
##   "coast":  PackedVector2Array  endpoints of all edges with no neighbor on the other side

## Coordinates are matched on a 0.1 grid (the map file uses 1 decimal).
const GRID := 10.0


static func build(regions: Dictionary) -> Dictionary:
	var open_edges := {}  # edge key -> {"id": String, "p": Vector2, "q": Vector2}
	var matched := {}  # edge key -> true
	var shared := {}
	for id in regions:
		var polygon: PackedVector2Array = (regions[id] as Region).polygon
		var count := polygon.size()
		for i in count:
			var p := polygon[i]
			var q := polygon[(i + 1) % count]
			var key := _edge_key(p, q)
			if open_edges.has(key) and not matched.has(key):
				var other: String = open_edges[key]["id"]
				var pair := _pair_key(other, id)
				# PackedVector2Array is a value type: modify a local copy, then store it back.
				var segments: PackedVector2Array = shared.get(pair, PackedVector2Array())
				segments.append(p)
				segments.append(q)
				shared[pair] = segments
				matched[key] = true
			elif not open_edges.has(key):
				open_edges[key] = {"id": id, "p": p, "q": q}
	var coast := PackedVector2Array()
	for key in open_edges:
		if not matched.has(key):
			coast.append(open_edges[key]["p"])
			coast.append(open_edges[key]["q"])
	return {"shared": shared, "coast": coast}


static func pair_key(id_a: String, id_b: String) -> String:
	return _pair_key(id_a, id_b)


static func _pair_key(id_a: String, id_b: String) -> String:
	return id_a + "|" + id_b if id_a < id_b else id_b + "|" + id_a


static func _edge_key(p: Vector2, q: Vector2) -> String:
	var a := Vector2i((p * GRID).round())
	var b := Vector2i((q * GRID).round())
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var swap := a
		a = b
		b = swap
	return "%d,%d,%d,%d" % [a.x, a.y, b.x, b.y]


## Splits shared edges into country borders (owners differ).
## Returns {"borders": PackedVector2Array, "player": PackedVector2Array}:
## "player" holds borders that touch player_id's territory, "borders" all the others.
static func split_by_owner(shared: Dictionary, regions: Dictionary, player_id: String) -> Dictionary:
	var borders := PackedVector2Array()
	var player_lines := PackedVector2Array()
	for pair in shared:
		var ids: PackedStringArray = (pair as String).split("|")
		if not regions.has(ids[0]) or not regions.has(ids[1]):
			continue
		var owner_a: String = (regions[ids[0]] as Region).country_id
		var owner_b: String = (regions[ids[1]] as Region).country_id
		if owner_a == owner_b:
			continue
		if player_id != "" and (owner_a == player_id or owner_b == player_id):
			player_lines.append_array(shared[pair])
		else:
			borders.append_array(shared[pair])
	return {"borders": borders, "player": player_lines}
