class_name IdGenerator
extends RefCounted
## Issues unique runtime IDs per type. Counters are saved with the campaign.
## Data-authored IDs (regions, countries) must be passed to observe().

var _counters: Dictionary = {}  # int type -> last issued number


func next_id(type: IdTypes.Type) -> String:
	var number: int = int(_counters.get(type, 0)) + 1
	_counters[type] = number
	return IdTypes.make(type, number)


## Makes sure future IDs never collide with an existing one.
func observe(id: String) -> void:
	var type := IdTypes.type_of(id)
	if type < 0:
		return
	var number := IdTypes.number_of(id)
	if number > int(_counters.get(type, 0)):
		_counters[type] = number


func reset() -> void:
	_counters.clear()


## JSON-safe: keys are type prefixes.
func to_dict() -> Dictionary:
	var out := {}
	for type in _counters:
		out[IdTypes.PREFIXES[type]] = _counters[type]
	return out


## JSON returns numbers as float, so values are cast back to int.
func from_dict(data: Dictionary) -> void:
	_counters.clear()
	for prefix in data:
		var index := IdTypes.PREFIXES.find(prefix)
		if index >= 0:
			_counters[index] = int(data[prefix])
