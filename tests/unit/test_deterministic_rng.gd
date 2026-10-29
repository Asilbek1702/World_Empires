extends "res://tests/test_base.gd"

const RngScript := preload("res://core/rng/deterministic_rng.gd")


func _init() -> void:
	print("test_deterministic_rng")
	_test_same_seed_same_sequence()
	_test_different_seed_different_sequence()
	_test_get_seed()
	_test_range_int_bounds()
	_test_range_float_bounds()
	_test_chance_edges()
	_test_pick()
	_test_state_restore()
	finish()


func _draw(rng, count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(rng.range_int(0, 1000000))
	return out


func _test_same_seed_same_sequence() -> void:
	var rng = RngScript.new()
	rng.set_seed(12345)
	var first := _draw(rng, 20)
	rng.set_seed(12345)
	var second := _draw(rng, 20)
	check(first == second, "same seed gives same sequence")
	var other = RngScript.new()
	other.set_seed(12345)
	check(_draw(other, 20) == first, "two instances with same seed match")
	rng.free()
	other.free()


func _test_different_seed_different_sequence() -> void:
	var rng = RngScript.new()
	rng.set_seed(1)
	var a := _draw(rng, 20)
	rng.set_seed(2)
	var b := _draw(rng, 20)
	check(a != b, "different seeds give different sequences")
	rng.free()


func _test_get_seed() -> void:
	var rng = RngScript.new()
	rng.set_seed(777)
	check(rng.get_seed() == 777, "get_seed returns the seed")
	rng.free()


func _test_range_int_bounds() -> void:
	var rng = RngScript.new()
	rng.set_seed(5)
	var ok := true
	var seen_min := false
	var seen_max := false
	for i in 2000:
		var v: int = rng.range_int(3, 6)
		if v < 3 or v > 6:
			ok = false
		seen_min = seen_min or v == 3
		seen_max = seen_max or v == 6
	check(ok, "range_int stays within bounds")
	check(seen_min and seen_max, "range_int reaches both inclusive bounds")
	check(rng.range_int(9, 9) == 9, "range_int with equal bounds")
	var swapped: int = rng.range_int(10, 4)
	check(swapped >= 4 and swapped <= 10, "range_int tolerates swapped bounds")
	rng.free()


func _test_range_float_bounds() -> void:
	var rng = RngScript.new()
	rng.set_seed(5)
	var ok := true
	for i in 2000:
		var v: float = rng.range_float(1.5, 2.5)
		if v < 1.5 or v > 2.5:
			ok = false
	check(ok, "range_float stays within bounds")
	rng.free()


func _test_chance_edges() -> void:
	var rng = RngScript.new()
	rng.set_seed(5)
	var never := true
	var always := true
	for i in 500:
		if rng.chance(0.0):
			never = false
		if not rng.chance(1.0):
			always = false
	check(never, "chance(0) is never true")
	check(always, "chance(1) is always true")
	rng.free()


func _test_pick() -> void:
	var rng = RngScript.new()
	rng.set_seed(5)
	check(rng.pick([]) == null, "pick on empty array returns null")
	var items := ["a", "b", "c"]
	var ok := true
	for i in 200:
		if not (rng.pick(items) in items):
			ok = false
	check(ok, "pick returns an element of the array")
	rng.free()


func _test_state_restore() -> void:
	var rng = RngScript.new()
	rng.set_seed(7)
	_draw(rng, 5)
	var saved: int = rng.get_state()
	var a := _draw(rng, 5)
	rng.set_state(saved)
	var b := _draw(rng, 5)
	check(a == b, "restoring state replays the same sequence")
	rng.free()
