class_name Region
extends RefCounted
## One territory of the map.
## STATIC part (geometry, neighbors, terrain) comes from data/regions/regions.json
## and is never saved. DYNAMIC part (owner, population, resources) is saved.

enum Terrain { PLAINS, FOREST, HILLS, MOUNTAIN, DESERT }

## Index in this array == value of Terrain. These are the names used in the JSON.
const TERRAIN_NAMES := ["plains", "forest", "hills", "mountain", "desert"]

# --- static ---
var id: String = ""
var center: Vector2 = Vector2.ZERO
var polygon: PackedVector2Array = PackedVector2Array()
var neighbors: Array[String] = []
var terrain: Terrain = Terrain.PLAINS
var area: float = 0.0  # polygon area in map units, derived

# --- dynamic ---
var country_id: String = ""  # "" = nobody owns it (Iter 6 assigns owners)
var population: int = 0  # Iter 8
var resources: Dictionary = {}  # natural deposits, later iterations

# --- derived index (never saved; WorldState rebuilds it from City.region_id) ---
var cities: Array[String] = []  # ids of the cities in this region, sorted


## Returns null if the data is malformed.
static func from_static_dict(data: Variant) -> Region:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not (d.get("id") is String) or not IdTypes.is_valid(d["id"], IdTypes.Type.REGION):
		return null
	var center_value: Variant = _to_vector2(d.get("center"))
	if center_value == null:
		return null
	var polygon_data: Variant = d.get("polygon")
	if not (polygon_data is Array) or (polygon_data as Array).size() < 3:
		return null
	var neighbor_data: Variant = d.get("neighbors")
	if not (neighbor_data is Array):
		return null
	var terrain_index := TERRAIN_NAMES.find(d.get("terrain"))
	if terrain_index < 0:
		return null

	var region := Region.new()
	region.id = d["id"]
	region.center = center_value
	region.terrain = terrain_index as Terrain
	for point in polygon_data:
		var vertex: Variant = _to_vector2(point)
		if vertex == null:
			return null
		region.polygon.append(vertex)
	for neighbor in neighbor_data:
		if not (neighbor is String):
			return null
		region.neighbors.append(neighbor)
	region.area = polygon_area(region.polygon)
	return region


## Absolute area of a simple polygon (shoelace formula).
static func polygon_area(points: PackedVector2Array) -> float:
	var sum := 0.0
	var count := points.size()
	for i in count:
		var a := points[i]
		var b := points[(i + 1) % count]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


func dynamic_to_dict() -> Dictionary:
	return {
		"country_id": country_id,
		"population": population,
		"resources": JsonNumbers.canonical(resources),
	}


## All-or-nothing. Returns false (and changes nothing) on malformed data.
func apply_dynamic(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if not (d.get("country_id") is String):
		return false
	var pop: Variant = d.get("population")
	var pop_is_whole: bool = typeof(pop) == TYPE_INT \
			or (typeof(pop) == TYPE_FLOAT and pop == floorf(pop))
	if not pop_is_whole or int(pop) < 0:
		return false
	if not (d.get("resources") is Dictionary):
		return false
	country_id = d["country_id"]
	population = int(pop)
	resources = JsonNumbers.canonical(d["resources"])
	return true


## Returns a Vector2, or null if the value is not a [x, y] pair of numbers.
static func _to_vector2(value: Variant) -> Variant:
	if not (value is Array) or (value as Array).size() != 2:
		return null
	var x: Variant = value[0]
	var y: Variant = value[1]
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if not (typeof(x) in numeric) or not (typeof(y) in numeric):
		return null
	return Vector2(float(x), float(y))
