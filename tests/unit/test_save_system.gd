extends "res://tests/test_base.gd"

const StateScript := preload("res://world/world_state.gd")
const RngScript := preload("res://core/rng/deterministic_rng.gd")
const PATH := "user://_test_save.json"


func _init() -> void:
	print("test_save_system")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://"))
	_cleanup()
	_test_roundtrip_date_and_seed()
	_test_large_seed_roundtrip()
	_test_rng_continues_after_load()
	_test_header_written()
	_test_overwrite_and_no_temp_left()
	_test_missing_file()
	_test_garbage_file()
	_test_wrong_shape()
	_test_regions_in_save_file()
	_test_cities_in_save_file()
	_test_future_version()
	_test_corrupt_world_state_changes_nothing()
	_cleanup()
	finish()


func _cleanup() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_json() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))


func _test_roundtrip_date_and_seed() -> void:
	var a = StateScript.new()
	a.new_game(12345)
	a.game_date.advance()
	a.game_date.advance()
	check(SaveSystem.save_to_json(PATH, a) == OK, "save succeeds")
	var b = StateScript.new()
	b.new_game(1)
	check(SaveSystem.load_from_json(PATH, b) == OK, "load succeeds")
	check(str(b.game_date) == "Autumn 1000", "date restored")
	check(b.game_date.turn_number == 3, "turn number restored")
	check(b.rng_seed == 12345, "seed restored")
	check(a.to_dict() == b.to_dict(), "whole state identical after round trip")
	a.free()
	b.free()


func _test_large_seed_roundtrip() -> void:
	var a = StateScript.new()
	a.new_game(9007199254740993)
	SaveSystem.save_to_json(PATH, a)
	var b = StateScript.new()
	SaveSystem.load_from_json(PATH, b)
	check(b.rng_seed == 9007199254740993, "seed above 2^53 survives the file exactly")
	a.free()
	b.free()


func _test_rng_continues_after_load() -> void:
	var state_a = StateScript.new()
	var rng_a = RngScript.new()
	state_a.new_game(42)
	rng_a.set_seed(42)
	for i in 7:
		rng_a.range_int(0, 1000000)
	SaveSystem.save_to_json(PATH, state_a, rng_a)

	var expected: Array = []
	for i in 5:
		expected.append(rng_a.range_int(0, 1000000))

	var state_b = StateScript.new()
	var rng_b = RngScript.new()
	check(SaveSystem.load_from_json(PATH, state_b, rng_b) == OK, "load with rng succeeds")
	var actual: Array = []
	for i in 5:
		actual.append(rng_b.range_int(0, 1000000))
	check(actual == expected, "RNG continues exactly where the save was made")
	check(rng_b.get_seed() == 42, "RNG seed restored")
	state_a.free()
	state_b.free()
	rng_a.free()
	rng_b.free()


func _test_header_written() -> void:
	var a = StateScript.new()
	SaveSystem.save_to_json(PATH, a)
	var root := _read_json()
	check(root.has("header") and root.has("world_state"), "file has header and world_state")
	check(int(root["header"]["save_version"]) == SaveFileFormat.SAVE_VERSION, "header has save_version")
	check(root["header"]["game_version"] == SaveFileFormat.GAME_VERSION, "header has game_version")
	check(root["header"]["metadata"]["date"] == "Spring 1000", "metadata has the date")
	a.free()


func _test_overwrite_and_no_temp_left() -> void:
	var a = StateScript.new()
	a.new_game(1)
	SaveSystem.save_to_json(PATH, a)
	a.game_date.advance()
	check(SaveSystem.save_to_json(PATH, a) == OK, "second save over existing file succeeds")
	var b = StateScript.new()
	SaveSystem.load_from_json(PATH, b)
	check(str(b.game_date) == "Summer 1000", "second save replaced the first")
	check(not FileAccess.file_exists(PATH + ".tmp"), "no temp file left behind")
	a.free()
	b.free()


func _test_missing_file() -> void:
	_cleanup()
	var b = StateScript.new()
	check(SaveSystem.load_from_json(PATH, b) == ERR_FILE_NOT_FOUND, "missing file -> ERR_FILE_NOT_FOUND")
	check(SaveSystem.last_error != "", "last_error is set on failure")
	b.free()


func _test_garbage_file() -> void:
	_write("this is not json {{{")
	var b = StateScript.new()
	check(SaveSystem.load_from_json(PATH, b) == ERR_PARSE_ERROR, "garbage -> ERR_PARSE_ERROR")
	_write("")
	check(SaveSystem.load_from_json(PATH, b) == ERR_PARSE_ERROR, "empty file -> ERR_PARSE_ERROR")
	b.free()


func _test_wrong_shape() -> void:
	var b = StateScript.new()
	_write('{"foo": 1}')
	check(SaveSystem.load_from_json(PATH, b) == ERR_INVALID_DATA, "object without header -> ERR_INVALID_DATA")
	_write("[1, 2, 3]")
	check(SaveSystem.load_from_json(PATH, b) == ERR_INVALID_DATA, "array -> ERR_INVALID_DATA")
	b.free()


func _test_future_version() -> void:
	var a = StateScript.new()
	SaveSystem.save_to_json(PATH, a)
	var root := _read_json()
	root["header"]["save_version"] = 999
	_write(JSON.stringify(root))
	var b = StateScript.new()
	b.new_game(77)
	var before: Dictionary = b.to_dict()
	check(SaveSystem.load_from_json(PATH, b) == ERR_FILE_UNRECOGNIZED, "future version -> ERR_FILE_UNRECOGNIZED")
	check("999" in SaveSystem.last_error, "error mentions the version")
	check(b.to_dict() == before, "state untouched after version rejection")
	a.free()
	b.free()


func _test_corrupt_world_state_changes_nothing() -> void:
	var a = StateScript.new()
	SaveSystem.save_to_json(PATH, a)
	var root := _read_json()
	root["world_state"]["game_date"]["season"] = 9
	_write(JSON.stringify(root))
	var b = StateScript.new()
	b.new_game(77)
	var rng = RngScript.new()
	rng.set_seed(5)
	var seed_before: int = rng.get_seed()
	var state_before: int = rng.get_state()
	var before: Dictionary = b.to_dict()
	check(SaveSystem.load_from_json(PATH, b, rng) == ERR_INVALID_DATA, "corrupt world_state -> ERR_INVALID_DATA")
	check(b.to_dict() == before, "state untouched after corrupt load")
	check(rng.get_seed() == seed_before and rng.get_state() == state_before, "rng untouched after corrupt load")
	a.free()
	b.free()
	rng.free()


func _test_regions_in_save_file() -> void:
	var a = StateScript.new()
	WorldBuilder.start_new_game(a, 31337)
	var ids: Array = a.regions.keys()
	var countries: Array = a.countries.keys()
	countries.sort()
	var moved := ""
	for rid in (a.countries[countries[0]] as Country).regions:
		if rid != (a.countries[countries[0]] as Country).capital_region:
			moved = rid
			break
	a.set_region_owner(moved, countries[1])
	(a.regions[ids[3]] as Region).population = 777
	a.set_player_country(countries[0])
	check(SaveSystem.save_to_json(PATH, a) == OK, "save with a full world succeeds")
	var text := FileAccess.get_file_as_string(PATH)
	check(not ("polygon" in text), "save file does not contain map geometry")
	check(text.length() < 120000, "save file stays small (%d bytes)" % text.length())
	var b = StateScript.new()
	check(SaveSystem.load_from_json(PATH, b) == OK, "load with a full world succeeds")
	check(b.regions.size() == a.regions.size() and b.countries.size() == a.countries.size(), "all regions and countries loaded")
	check((b.regions[ids[3]] as Region).population == 777, "region population survived the file")
	check((b.regions[moved] as Region).country_id == countries[1], "a transferred region keeps its new owner")
	check(b.get_player_country() != null and b.get_player_country().id == countries[0], "player country survived the file")
	check((b.countries[countries[0]] as Country).name == (a.countries[countries[0]] as Country).name, "country name survived the file")
	check((b.regions[ids[3]] as Region).neighbors == (a.regions[ids[3]] as Region).neighbors, "static neighbors restored from the map file")
	check(WorldIntegrity.check(b).is_empty(), "loaded world is consistent")
	check(a.to_dict() == b.to_dict(), "whole world identical after file round trip")
	a.free()
	b.free()


func _test_cities_in_save_file() -> void:
	var a = StateScript.new()
	WorldBuilder.start_new_game(a, 5)
	var ids: Array = a.cities.keys()
	ids.sort()
	var city: City = a.cities[ids[1]]
	var order := ConstructionOrder.new()
	order.building_id = "factory"
	order.seasons_total = 6
	order.seasons_done = 3
	city.queue.append(order)
	city.buildings.append("farm")
	check(SaveSystem.save_to_json(PATH, a) == OK, "save with cities succeeds")
	var b = StateScript.new()
	check(SaveSystem.load_from_json(PATH, b) == OK, "load with cities succeeds")
	var loaded: City = b.cities[city.id]
	check(loaded.queue[0].building_id == "factory" and loaded.queue[0].seasons_done == 3, "construction progress survived the file")
	check(loaded.buildings == ["farm"], "completed buildings survived the file")
	check(loaded.name == city.name, "the city name survived the file")
	check(a.to_dict() == b.to_dict(), "whole world with cities identical after the file round trip")
	a.free()
	b.free()
