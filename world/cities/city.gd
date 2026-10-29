class_name City
extends RefCounted
## A city: the economic center of a region. Saved completely (name, region, level,
## buildings, queue), because cities can be founded during a campaign.
## The same dictionary format is used in data/cities/cities.json (buildings and queue optional).

enum Level { VILLAGE, SETTLEMENT, TOWN, CITY, MAJOR_CITY, METROPOLIS }

## Index in this array == value of Level. These are the names used in the files.
const LEVEL_NAMES := ["village", "settlement", "town", "city", "major_city", "metropolis"]

var id: String = ""
var name: String = ""
var region_id: String = ""
var level: Level = Level.SETTLEMENT
var buildings: Array[String] = []  # completed, in the order they were finished
var queue: Array[ConstructionOrder] = []  # only the first order progresses


func has_building(building_id: String) -> bool:
	return buildings.has(building_id)


func is_queued(building_id: String) -> bool:
	for order in queue:
		if order.building_id == building_id:
			return true
	return false


func level_name() -> String:
	return LEVEL_NAMES[level]


## Moves construction forward by one season. Only the first order in the queue progresses.
## Returns the id of the building that was completed this season, or "" if none.
func advance_construction() -> String:
	if queue.is_empty():
		return ""
	var order: ConstructionOrder = queue[0]
	order.seasons_done += 1
	if order.seasons_done < order.seasons_total:
		return ""
	queue.pop_front()
	if not buildings.has(order.building_id):
		buildings.append(order.building_id)
	return order.building_id


func to_dict() -> Dictionary:
	var queue_data: Array = []
	for order in queue:
		queue_data.append(order.to_dict())
	return {
		"id": id,
		"name": name,
		"region_id": region_id,
		"level": level_name(),
		"buildings": buildings.duplicate(),
		"queue": queue_data,
	}


## Returns null if the data is malformed. "buildings" and "queue" default to empty.
static func from_dict(data: Variant) -> City:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not (d.get("id") is String) or not IdTypes.is_valid(d["id"], IdTypes.Type.CITY):
		return null
	if not (d.get("name") is String) or (d["name"] as String).strip_edges() == "":
		return null
	if not (d.get("region_id") is String) or not IdTypes.is_valid(d["region_id"], IdTypes.Type.REGION):
		return null
	var level_index := LEVEL_NAMES.find(d.get("level"))
	if level_index < 0:
		return null
	var building_list: Variant = d.get("buildings", [])
	var queue_list: Variant = d.get("queue", [])
	if not (building_list is Array) or not (queue_list is Array):
		return null

	var city := City.new()
	city.id = d["id"]
	city.name = d["name"]
	city.region_id = d["region_id"]
	city.level = level_index as Level
	for building_id in building_list:
		if not (building_id is String) or city.buildings.has(building_id):
			return null
		city.buildings.append(building_id)
	for entry in queue_list:
		var order := ConstructionOrder.from_dict(entry)
		if order == null:
			return null
		city.queue.append(order)
	return city
