class_name GameDate
extends RefCounted
## Calendar date. 1 turn = 1 season. 4 turns = 1 year.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASONS_PER_YEAR := 4

var year: int
var season: Season
var turn_number: int


func _init(
		p_year: int = 1000,
		p_season: Season = Season.SPRING,
		p_turn_number: int = 1) -> void:
	year = p_year
	season = p_season
	turn_number = p_turn_number


## Moves the date forward by exactly one season.
func advance() -> void:
	turn_number += 1
	if season == Season.WINTER:
		season = Season.SPRING
		year += 1
	else:
		season = (season + 1) as Season


## Independent snapshot (GameDate is mutable).
func copy() -> GameDate:
	return GameDate.new(year, season, turn_number)


func season_name() -> String:
	return str(Season.keys()[season]).capitalize()


func to_dict() -> Dictionary:
	return {"year": year, "season": int(season), "turn_number": turn_number}


## Returns null if the data is malformed. JSON gives floats, so whole floats are accepted.
static func from_dict(data: Variant) -> GameDate:
	if not (data is Dictionary):
		return null
	for key in ["year", "season", "turn_number"]:
		if not data.has(key) or not _is_whole_number(data[key]):
			return null
	var season_index := int(data["season"])
	if season_index < 0 or season_index >= SEASONS_PER_YEAR:
		return null
	return GameDate.new(int(data["year"]), season_index as Season, int(data["turn_number"]))


func _to_string() -> String:
	return "%s %d" % [season_name(), year]


static func _is_whole_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and value == floorf(value)
