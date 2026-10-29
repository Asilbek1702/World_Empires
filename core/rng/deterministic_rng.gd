extends Node
## Autoload "GameRNG".
## Seeded RNG. Same seed + same call sequence = same results.
## All gameplay randomness must go through this node.

var _rng := RandomNumberGenerator.new()
var _seed: int = 0


func _init() -> void:
	set_seed(0)


func set_seed(new_seed: int) -> void:
	_seed = new_seed
	_rng.seed = new_seed


func get_seed() -> int:
	return _seed


## Non-deterministic. Use only to pick the seed of a NEW campaign.
func seed_from_time() -> void:
	set_seed(Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system() * 1000.0))


## Full generator position. Save it with the campaign (Iter 3+).
func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state


func next_float() -> float:
	return _rng.randf()


## Inclusive on both ends.
func range_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(mini(min_value, max_value), maxi(min_value, max_value))


func range_float(min_value: float, max_value: float) -> float:
	return _rng.randf_range(minf(min_value, max_value), maxf(min_value, max_value))


## True with probability p (0.0 .. 1.0).
func chance(p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	return _rng.randf() < p


## Random element, or null for an empty array.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[range_int(0, items.size() - 1)]
