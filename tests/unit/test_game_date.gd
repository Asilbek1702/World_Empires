extends "res://tests/test_base.gd"


func _init() -> void:
	print("test_game_date")
	_test_default_start()
	_test_advance_within_year()
	_test_year_rollover()
	_test_full_year_cycle()
	_test_dict_roundtrip()
	_test_from_dict_rejects_bad_data()
	_test_copy_is_independent()
	finish()


func _test_default_start() -> void:
	var d := GameDate.new()
	check(d.year == 1000, "default year is 1000")
	check(d.season == GameDate.Season.SPRING, "default season is Spring")
	check(d.turn_number == 1, "default turn is 1")


func _test_advance_within_year() -> void:
	var d := GameDate.new(1000, GameDate.Season.SPRING, 1)
	d.advance()
	check(d.season == GameDate.Season.SUMMER, "Spring -> Summer")
	check(d.year == 1000, "year unchanged after Spring -> Summer")
	d.advance()
	check(d.season == GameDate.Season.AUTUMN, "Summer -> Autumn")
	d.advance()
	check(d.season == GameDate.Season.WINTER, "Autumn -> Winter")
	check(d.year == 1000, "year unchanged until Winter ends")


func _test_year_rollover() -> void:
	var d := GameDate.new(1939, GameDate.Season.WINTER, 40)
	d.advance()
	check(d.season == GameDate.Season.SPRING, "Winter -> Spring")
	check(d.year == 1940, "Winter -> Spring increments year")
	check(d.turn_number == 41, "turn number increments across rollover")


func _test_full_year_cycle() -> void:
	var d := GameDate.new(1000, GameDate.Season.SPRING, 1)
	for i in GameDate.SEASONS_PER_YEAR:
		d.advance()
	check(d.year == 1001, "4 advances = +1 year")
	check(d.season == GameDate.Season.SPRING, "4 advances return to Spring")
	check(d.turn_number == 5, "4 advances = +4 turns")
	check(str(d) == "Spring 1001", "to_string format")


func _test_dict_roundtrip() -> void:
	var d := GameDate.new(1942, GameDate.Season.AUTUMN, 177)
	var copy := GameDate.from_dict(d.to_dict())
	check(copy != null and copy.year == 1942, "from_dict restores year")
	check(copy != null and copy.season == GameDate.Season.AUTUMN, "from_dict restores season")
	check(copy != null and copy.turn_number == 177, "from_dict restores turn")
	var via_json := GameDate.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	check(via_json != null and str(via_json) == "Autumn 1942", "date survives JSON (float -> int)")


func _test_from_dict_rejects_bad_data() -> void:
	var good := {"year": 1000, "season": 0, "turn_number": 1}
	check(GameDate.from_dict(good) != null, "baseline dict is accepted")
	check(GameDate.from_dict(null) == null, "null rejected")
	check(GameDate.from_dict([1, 2, 3]) == null, "non-dictionary rejected")
	check(GameDate.from_dict({"year": 1000, "season": 0}) == null, "missing key rejected")
	check(GameDate.from_dict({"year": 1000, "season": 4, "turn_number": 1}) == null, "season 4 rejected")
	check(GameDate.from_dict({"year": 1000, "season": -1, "turn_number": 1}) == null, "season -1 rejected")
	check(GameDate.from_dict({"year": "1000", "season": 0, "turn_number": 1}) == null, "string year rejected")
	check(GameDate.from_dict({"year": 1000.5, "season": 0, "turn_number": 1}) == null, "fractional year rejected")


func _test_copy_is_independent() -> void:
	var d := GameDate.new(1914, GameDate.Season.WINTER, 20)
	var c := d.copy()
	d.advance()
	check(str(c) == "Winter 1914" and c.turn_number == 20, "copy is not changed by advancing the original")
	check(str(d) == "Spring 1915", "original advanced normally")
