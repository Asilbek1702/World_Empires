extends Node
## Autoload "WorldState". Single source of truth for the whole simulation.
## UI and AI only read it and send Commands (Iter 4).
## Entity dictionaries hold objects. Only their DYNAMIC state is saved.
## Static data (map geometry) is reloaded from data/ when a save is loaded.
## Territory rules (who owns what) are checked by WorldIntegrity.

## Emitted after new_game() or a successful from_dict().
signal state_replaced
## Emitted by set_region_owner(). Borders and map colors follow this.
signal region_owner_changed(region_id: String, old_owner: String, new_owner: String)
## Emitted by set_player_country().
signal player_country_changed(country_id: String)
## Emitted when a city's buildings or construction queue change.
signal city_changed(city_id: String)
## Emitted exactly once when a construction finishes.
signal building_completed(city_id: String, building_id: String)
## Emitted when a country's current research or its progress changes.
signal research_changed(country_id: String)
## Emitted exactly once when a research finishes.
signal technology_researched(country_id: String, technology_id: String)
## Emitted when units, armies or generals change (recruiting, forming an army, naming a general).
signal military_changed

var game_date: GameDate = GameDate.new()
var rng_seed: int = 0
## Generator position at the moment of the last save. Not kept live (see SaveSystem).
var rng_state: int = 0

var countries: Dictionary = {}  # CountryID -> Country
var regions: Dictionary = {}  # RegionID -> Region
var cities: Dictionary = {}  # CityID -> City
var units: Dictionary = {}  # UnitID -> Unit
var armies: Dictionary = {}  # ArmyID -> Army
var generals: Dictionary = {}  # GeneralID -> General
## Issues unit and army ids. Its counters are saved, so ids are never reused.
var id_generator: IdGenerator = IdGenerator.new()


## p_regions / p_countries / p_cities: freshly loaded objects (see WorldBuilder). Empty = none.
## The caller guarantees they are consistent with each other (WorldIntegrity).
func new_game(p_seed: int = 0, start_date: GameDate = null, p_regions: Dictionary = {},
		p_countries: Dictionary = {}, p_cities: Dictionary = {}, p_generals: Dictionary = {}) -> void:
	game_date = start_date if start_date != null else GameDate.new()
	rng_seed = p_seed
	rng_state = 0
	countries = p_countries
	regions = p_regions
	cities = p_cities
	_rebuild_city_index(regions, cities)
	units = {}
	armies = {}
	generals = p_generals
	id_generator = IdGenerator.new()
	for general_id in generals:
		id_generator.observe(general_id)
	state_replaced.emit()


## 64-bit values are stored as strings: JSON numbers are floats and lose
## precision above 2^53.
func to_dict() -> Dictionary:
	return {
		"game_date": game_date.to_dict(),
		"rng_seed": str(rng_seed),
		"rng_state": str(rng_state),
		"countries": _countries_to_dict(),
		"regions": _regions_to_dict(),
		"cities": _cities_to_dict(),
		"units": _entities_to_dict(units),
		"armies": _entities_to_dict(armies),
		"generals": _entities_to_dict(generals),
		"id_counters": id_generator.to_dict(),
	}


## All-or-nothing: on any error the current state is left untouched.
func from_dict(data: Dictionary) -> Error:
	var date := GameDate.from_dict(data.get("game_date"))
	if date == null:
		return ERR_INVALID_DATA
	var seed_text: Variant = data.get("rng_seed")
	var state_text: Variant = data.get("rng_state")
	if not _is_int64_text(seed_text) or not _is_int64_text(state_text):
		return ERR_INVALID_DATA
	for key in ["countries", "regions", "cities", "units", "armies", "generals", "id_counters"]:
		if not (data.get(key) is Dictionary):
			return ERR_INVALID_DATA
	var new_regions := {}
	var region_error := _restore_regions(data["regions"], new_regions)
	if region_error != OK:
		return region_error
	var new_countries := {}
	if not _restore_countries(data["countries"], new_countries):
		return ERR_INVALID_DATA
	_rebuild_region_index(new_countries, new_regions)
	if not WorldIntegrity.check_territory(new_countries, new_regions, true).is_empty():
		return ERR_INVALID_DATA
	var new_cities := {}
	if not _restore_cities(data["cities"], new_cities):
		return ERR_INVALID_DATA
	_rebuild_city_index(new_regions, new_cities)
	if not WorldIntegrity.check_cities(new_cities, new_regions, BuildingCatalog.get_all()).is_empty():
		return ERR_INVALID_DATA

	if not WorldIntegrity.check_technologies(new_countries, TechnologyCatalog.get_all()).is_empty():
		return ERR_INVALID_DATA
	var new_units := {}
	var new_armies := {}
	var new_generals := {}
	if not _restore_military(data, new_units, new_armies, new_generals):
		return ERR_INVALID_DATA
	if not WorldIntegrity.check_military(new_countries, new_regions, new_units, new_armies,
			new_generals, UnitCatalog.get_all()).is_empty():
		return ERR_INVALID_DATA
	var new_ids := IdGenerator.new()
	new_ids.from_dict(data["id_counters"])
	for entities in [new_units, new_armies, new_generals]:
		for entity_id in entities:
			new_ids.observe(entity_id)

	game_date = date
	rng_seed = (seed_text as String).to_int()
	rng_state = (state_text as String).to_int()
	countries = new_countries
	regions = new_regions
	cities = new_cities
	units = new_units
	armies = new_armies
	generals = new_generals
	id_generator = new_ids
	state_replaced.emit()
	return OK


## Moves a region to another country and keeps Country.regions in sync.
## LOW LEVEL: no gameplay rules. Gameplay code must use TransferRegionCommand.
func set_region_owner(region_id: String, new_owner_id: String) -> Error:
	if not regions.has(region_id) or not countries.has(new_owner_id):
		return ERR_DOES_NOT_EXIST
	var region: Region = regions[region_id]
	var old_owner := region.country_id
	if old_owner == new_owner_id:
		return OK
	if countries.has(old_owner):
		(countries[old_owner] as Country).regions.erase(region_id)
	region.country_id = new_owner_id
	var new_owner: Country = countries[new_owner_id]
	new_owner.regions.append(region_id)
	new_owner.regions.sort()
	region_owner_changed.emit(region_id, old_owner, new_owner_id)
	return OK


## The country the human controls, or null before one is chosen.
func get_player_country() -> Country:
	for id in countries:
		if (countries[id] as Country).is_player_controlled:
			return countries[id]
	return null


## Marks exactly one country as player controlled.
## LOW LEVEL: gameplay code uses SelectPlayerCountryCommand.
func set_player_country(country_id: String) -> Error:
	if not countries.has(country_id):
		return ERR_DOES_NOT_EXIST
	for id in countries:
		(countries[id] as Country).is_player_controlled = (id == country_id)
	player_country_changed.emit(country_id)
	return OK


static func _is_int64_text(value: Variant) -> bool:
	return value is String and (value as String).is_valid_int()


func _regions_to_dict() -> Dictionary:
	var out := {}
	for id in regions:
		out[id] = (regions[id] as Region).dynamic_to_dict()
	return out


## Rebuilds Region objects: static data from the map file + saved dynamic data.
## Fills `target` only; touches no state.
static func _restore_regions(saved: Dictionary, target: Dictionary) -> Error:
	if saved.is_empty():
		return OK
	var static_regions := MapLoader.load_regions()
	if static_regions.is_empty():
		return ERR_FILE_NOT_FOUND
	for id in saved:
		if not static_regions.has(id):
			return ERR_INVALID_DATA
		var region: Region = static_regions[id]
		if not region.apply_dynamic(saved[id]):
			return ERR_INVALID_DATA
		target[id] = region
	return OK


func _countries_to_dict() -> Dictionary:
	var out := {}
	for id in countries:
		out[id] = (countries[id] as Country).to_dict()
	return out


## Fills `target` only. Returns false if any entry is malformed or keyed wrongly.
static func _restore_countries(saved: Dictionary, target: Dictionary) -> bool:
	for id in saved:
		var country := Country.from_dict(saved[id])
		if country == null or country.id != id:
			return false
		target[id] = country
	return true


## Country.regions is derived: rebuilt from the region owners (sorted).
static func _rebuild_region_index(country_dict: Dictionary, region_dict: Dictionary) -> void:
	for id in region_dict:
		var owner_id: String = (region_dict[id] as Region).country_id
		if country_dict.has(owner_id):
			(country_dict[owner_id] as Country).regions.append(id)
	for cid in country_dict:
		(country_dict[cid] as Country).regions.sort()


func _cities_to_dict() -> Dictionary:
	var out := {}
	for id in cities:
		out[id] = (cities[id] as City).to_dict()
	return out


## Fills `target` only. Returns false if any entry is malformed or keyed wrongly.
static func _restore_cities(saved: Dictionary, target: Dictionary) -> bool:
	for id in saved:
		var city := City.from_dict(saved[id])
		if city == null or city.id != id:
			return false
		target[id] = city
	return true


## Region.cities is derived: rebuilt from City.region_id (sorted).
static func _rebuild_city_index(region_dict: Dictionary, city_dict: Dictionary) -> void:
	for rid in region_dict:
		(region_dict[rid] as Region).cities.clear()
	for cid in city_dict:
		var region = region_dict.get((city_dict[cid] as City).region_id)
		if region != null:
			(region as Region).cities.append(cid)
	for rid in region_dict:
		(region_dict[rid] as Region).cities.sort()


static func _entities_to_dict(entities: Dictionary) -> Dictionary:
	var out := {}
	for id in entities:
		out[id] = entities[id].to_dict()
	return out


## Fills the three targets only. Returns false if any entry is malformed or keyed wrongly.
static func _restore_military(data: Dictionary, target_units: Dictionary,
		target_armies: Dictionary, target_generals: Dictionary) -> bool:
	for id in data["units"]:
		var unit := Unit.from_dict(data["units"][id])
		if unit == null or unit.id != id:
			return false
		target_units[id] = unit
	for id in data["armies"]:
		var army := Army.from_dict(data["armies"][id])
		if army == null or army.id != id:
			return false
		target_armies[id] = army
	for id in data["generals"]:
		var general := General.from_dict(data["generals"][id])
		if general == null or general.id != id:
			return false
		target_generals[id] = general
	return true
