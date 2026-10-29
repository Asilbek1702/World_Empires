extends "res://tests/test_base.gd"


func _init() -> void:
	print("test_json_numbers")
	check(JsonNumbers.canonical(2.0) is int and JsonNumbers.canonical(2.0) == 2, "whole float becomes int")
	check(JsonNumbers.canonical(2.5) is float and JsonNumbers.canonical(2.5) == 2.5, "fractional float stays float")
	check(JsonNumbers.canonical(-3.0) == -3 and JsonNumbers.canonical(-3.0) is int, "negative whole float becomes int")
	check(JsonNumbers.canonical(7) is int, "int stays int")
	check(JsonNumbers.canonical("a") == "a" and JsonNumbers.canonical(true) == true, "other types pass through")
	check(JsonNumbers.canonical(INF) is float, "infinity is left alone")
	var nested := {"a": 1.0, "b": [2.0, 2.5, {"c": 3.0}], "d": {"e": 4.0}}
	var result: Dictionary = JsonNumbers.canonical(nested)
	check(result == {"a": 1, "b": [2, 2.5, {"c": 3}], "d": {"e": 4}}, "nested values are converted")
	check(nested["a"] is float, "the original is not modified")
	var via_json: Variant = JSON.parse_string(JSON.stringify({"iron": 7, "wood": 1.5}))
	check(JsonNumbers.canonical(via_json) == {"iron": 7, "wood": 1.5}, "ints survive a JSON round trip")
	finish()
