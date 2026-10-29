class_name PopulationModel
extends RefCounted
## The growth formula, as a pure function (no state, easy to test).
##
##   delta = round(population * rate * (1 - population / capacity))
##
## Far below capacity the region grows by about `rate` per season. The closer it
## gets to capacity the slower it grows. At capacity it stops. Above capacity
## (capacity shrank) the same formula gives a negative delta: the region shrinks,
## but by at most MAX_DECLINE_PER_SEASON per season.
## Guarantees: never negative, never rises above capacity, 0 stays 0.


static func next_population(current: int, capacity: int,
		rate: float = PopulationConfig.GROWTH_RATE_PER_SEASON) -> int:
	if current <= 0:
		return 0
	var max_decline := int(current * PopulationConfig.MAX_DECLINE_PER_SEASON)
	var delta: int
	if capacity <= 0:
		delta = -max_decline
	else:
		delta = roundi(current * rate * (1.0 - float(current) / float(capacity)))
		delta = maxi(delta, -max_decline)
	var result := maxi(current + delta, 0)
	if current <= capacity:
		result = mini(result, capacity)
	return result
