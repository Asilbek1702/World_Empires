class_name Army
extends RefCounted
## An army: units in one region, optionally led by one general.
## Saved completely. Iter 12 is data only: supply, movement_target and order are
## placeholders for iterations 13 (movement) and 15 (battles).

const MAX_UNITS := 20
const MAX_NAME_LENGTH := 40
const ORDERS := ["none"]

var id: String = ""
var name: String = ""
var country_id: String = ""
var region_id: String = ""  # position on the map
var units: Array[String] = []  # UnitIDs, 1..MAX_UNITS
var general_id: String = ""  # "" = no general
var supply: float = 100.0  # 0..100, placeholder
var movement_target: String = ""  # RegionID or "", placeholder
var order: String = "none"  # placeholder


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"country_id": country_id,
		"region_id": region_id,
		"units": units.duplicate(),
		"general_id": general_id,
		"supply": supply,
		"movement_target": movement_target,
		"order": order,
	}


## Returns null if the data is malformed.
static func from_dict(data: Variant) -> Army:
	if not (data is Dictionary):
		return null
	var d: Dictionary = data
	if not (d.get("id") is String) or not IdTypes.is_valid(d["id"], IdTypes.Type.ARMY):
		return null
	if not valid_name(d.get("name")):
		return null
	if not (d.get("country_id") is String) or not IdTypes.is_valid(d["country_id"], IdTypes.Type.COUNTRY):
		return null
	if not (d.get("region_id") is String) or not IdTypes.is_valid(d["region_id"], IdTypes.Type.REGION):
		return null
	var unit_list: Variant = d.get("units")
	if not (unit_list is Array) or (unit_list as Array).is_empty() or (unit_list as Array).size() > MAX_UNITS:
		return null
	var general: Variant = d.get("general_id")
	if not (general is String) or (general != "" and not IdTypes.is_valid(general, IdTypes.Type.GENERAL)):
		return null
	var supply_value: Variant = d.get("supply")
	if not (typeof(supply_value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(supply_value) \
			or supply_value < 0 or supply_value > 100:
		return null
	var target: Variant = d.get("movement_target")
	if not (target is String) or (target != "" and not IdTypes.is_valid(target, IdTypes.Type.REGION)):
		return null
	if not (d.get("order") is String) or not ORDERS.has(d["order"]):
		return null

	var army := Army.new()
	army.id = d["id"]
	army.name = d["name"]
	army.country_id = d["country_id"]
	army.region_id = d["region_id"]
	for unit_id in unit_list:
		if not (unit_id is String) or not IdTypes.is_valid(unit_id, IdTypes.Type.UNIT) or army.units.has(unit_id):
			return null
		army.units.append(unit_id)
	army.general_id = general
	army.supply = EconomyModel.round_money(float(supply_value))
	army.movement_target = target
	army.order = d["order"]
	return army


static func valid_name(value: Variant) -> bool:
	return value is String and (value as String).strip_edges() != "" \
			and (value as String).length() <= MAX_NAME_LENGTH
