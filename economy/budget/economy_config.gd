class_name EconomyConfig
extends RefCounted
## Balance constants of the MVP economy. One place to tune.
## All amounts are PER SEASON. Only GOLD is accumulated (Country.treasury) in Iter 9.
## The other resources are production figures: industry is spent on construction (Iter 10),
## science on research (Iter 11), manpower on recruitment (Iter 12).

const GOLD_PER_PERSON := 0.0005
const FOOD_PER_PERSON := 0.001
const INDUSTRY_PER_PERSON := 0.0002
const SCIENCE_PER_PERSON := 0.00005
const MANPOWER_PER_PERSON := 0.002

## Food multiplier by terrain. Index = Region.Terrain: PLAINS, FOREST, HILLS, MOUNTAIN, DESERT.
const FERTILITY := [1.3, 0.9, 0.8, 0.4, 0.3]

## Gold the state pays per region it owns (administration).
## A thin region (desert, mountain) can cost more than it brings in.
const ADMIN_COST_PER_REGION := 50.0

const STARTING_TREASURY := 500.0

## Manpower is a stock: each season the country's manpower output is added to it,
## recruiting takes from it (Iter 12).
const STARTING_MANPOWER := 5000.0
const MANPOWER_LIMIT := 1.0e7

## Safety ceiling so the treasury can never run away to infinity.
## 1e11 keeps every amount within the ~15 significant digits JSON can store exactly.
const TREASURY_LIMIT := 1.0e11
