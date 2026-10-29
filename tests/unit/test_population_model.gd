extends "res://tests/test_base.gd"
## The growth formula, tested as a pure function.

const RATE := PopulationConfig.GROWTH_RATE_PER_SEASON


func _init() -> void:
	print("test_population_model")
	_test_formula_values()
	_test_rate_matches_config()
	_test_growth_slows_near_capacity()
	_test_zero_stays_zero()
	_test_over_capacity_declines_but_is_bounded()
	_test_never_negative_never_above_capacity()
	_test_long_run_converges_to_capacity()
	_test_tiny_populations()
	finish()


func _test_formula_values() -> void:
	# 1000 * 0.01 * (1 - 1000/2000) = 5
	check(PopulationModel.next_population(1000, 2000, 0.01) == 1005, "1000 of 2000 at 1% -> 1005")
	check(PopulationModel.next_population(100000, 1000000, 0.01) == 100900, "100000 of 1000000 at 1% -> 100900")
	check(PopulationModel.next_population(500000, 500000, 0.01) == 500000, "at capacity nothing changes")


func _test_rate_matches_config() -> void:
	check(RATE == 0.01, "the configured growth rate is 1% per season")
	# far below capacity: growth is ~ rate
	var grown := PopulationModel.next_population(1000000, 1000000000)
	var measured := float(grown - 1000000) / 1000000.0
	check(absf(measured - RATE) < 0.0001, "far below capacity the growth equals the configured rate (%.5f)" % measured)
	# half full: growth is ~ rate / 2
	var half := PopulationModel.next_population(500000, 1000000)
	check(half == 500000 + 2500, "half full: growth is rate * 0.5 (got +%d)" % (half - 500000))


func _test_growth_slows_near_capacity() -> void:
	var capacity := 1000000
	# relative growth (per person) falls steadily as the region fills up
	var last_rate := 1.0
	var rate_falls := true
	for population in [100000, 300000, 500000, 700000, 900000, 990000]:
		var gain: int = PopulationModel.next_population(population, capacity) - population
		var rate := float(gain) / float(population)
		if rate > last_rate:
			rate_falls = false
		last_rate = rate
	check(rate_falls, "growth per person shrinks as the region fills up")
	# in absolute numbers the gain peaks around half capacity (classic logistic curve)
	var gain_low: int = PopulationModel.next_population(100000, capacity) - 100000
	var gain_half: int = PopulationModel.next_population(500000, capacity) - 500000
	var gain_high: int = PopulationModel.next_population(900000, capacity) - 900000
	check(gain_half > gain_low and gain_half > gain_high, "absolute growth peaks at about half capacity")


func _test_zero_stays_zero() -> void:
	check(PopulationModel.next_population(0, 1000000) == 0, "0 stays 0")
	check(PopulationModel.next_population(-5, 1000000) == 0, "a negative input is treated as 0")


func _test_over_capacity_declines_but_is_bounded() -> void:
	var after := PopulationModel.next_population(2000, 1000)
	check(after < 2000, "over capacity the population shrinks")
	check(after >= 2000 - int(2000 * PopulationConfig.MAX_DECLINE_PER_SEASON), "the decline is bounded per season")
	var crash := PopulationModel.next_population(1000000, 10)
	check(crash == 1000000 - int(1000000 * PopulationConfig.MAX_DECLINE_PER_SEASON), "a huge excess still shrinks by at most the maximum")
	var no_room := PopulationModel.next_population(1000, 0)
	check(no_room < 1000 and no_room >= 0, "capacity 0 shrinks the population, never below 0")


func _test_never_negative_never_above_capacity() -> void:
	var ok_negative := true
	var ok_ceiling := true
	for population in [0, 1, 2, 7, 99, 1000, 123456, 99999999]:
		for capacity in [0, 1, 5, 100, 1000, 123456, 1000000, 999999999]:
			var next := PopulationModel.next_population(population, capacity)
			if next < 0:
				ok_negative = false
			if population <= capacity and next > capacity:
				ok_ceiling = false
	check(ok_negative, "the result is never negative")
	check(ok_ceiling, "below capacity the result never exceeds capacity")


func _test_long_run_converges_to_capacity() -> void:
	var capacity := 800000
	var population := 80000
	var never_decreased := true
	var never_above := true
	for season in 3000:
		var next := PopulationModel.next_population(population, capacity)
		if next < population:
			never_decreased = false
		if next > capacity:
			never_above = false
		population = next
	check(never_decreased, "a growing region never shrinks on the way up")
	check(never_above, "a growing region never overshoots capacity")
	check(population > capacity * 0.99, "after a long time the region is nearly full (%d of %d)" % [population, capacity])


func _test_tiny_populations() -> void:
	var next := PopulationModel.next_population(30, 1000)
	check(next >= 30 and next <= 1000, "a tiny population stays sane")
