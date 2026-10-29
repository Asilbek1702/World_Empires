class_name PopulationConfig
extends RefCounted
## Balance constants of the population model (MVP). One place to tune.
## Later iterations replace the terrain table with historical data.

## Net growth per season when there is plenty of room (births - deaths).
## 0.01 = +1% per season. It slows down as a region fills up (see PopulationModel).
const GROWTH_RATE_PER_SEASON := 0.01

## Above capacity a region shrinks, but never faster than this per season.
const MAX_DECLINE_PER_SEASON := 0.05

## People per 1000 map-area units, by terrain. Index = Region.Terrain value:
## PLAINS, FOREST, HILLS, MOUNTAIN, DESERT.
const DENSITY_PER_1000_AREA := [150000.0, 70000.0, 60000.0, 25000.0, 20000.0]

## Capacity = base population * this. Start is ~45% of capacity, so there is room to grow.
const CAPACITY_FACTOR := 2.2

## Starting population = base population * a factor in this range (fixed per region id).
const START_VARIATION_MIN := 0.8
const START_VARIATION_MAX := 1.2


## People the terrain supports on this region's area, before the capacity factor.
static func base_population(region: Region) -> float:
	return DENSITY_PER_1000_AREA[region.terrain] * region.area / 1000.0


## Most people the region can hold (a ceiling for growth).
static func capacity(region: Region) -> int:
	return int(base_population(region) * CAPACITY_FACTOR)


## Starting population of a new game. Same region -> same number, every time.
static func initial_population(region: Region) -> int:
	return int(base_population(region) * variation(region.id))


## Factor in [START_VARIATION_MIN, START_VARIATION_MAX], fixed by the region id.
static func variation(region_id: String) -> float:
	return START_VARIATION_MIN + (START_VARIATION_MAX - START_VARIATION_MIN) * _hash01(region_id)


## FNV-1a 32-bit. Stable on every platform (unlike hash()).
static func _hash01(text: String) -> float:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h / 4294967295.0
