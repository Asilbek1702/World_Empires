class_name WorldIntegrity
extends RefCounted
## Consistency rules of the territory model (spec 4.87, 4.107).
## Returns a list of human-readable problems. Empty list = consistent.


static func check(state: Node, allow_unowned: bool = false) -> Array[String]:
	var problems := check_territory(state.countries, state.regions, allow_unowned)
	problems.append_array(check_cities(state.cities, state.regions, BuildingCatalog.get_all()))
	return problems


## allow_unowned: true accepts regions whose country_id is "" (neutral land).
static func check_territory(countries: Dictionary, regions: Dictionary,
		allow_unowned: bool) -> Array[String]:
	var problems: Array[String] = []

	var owned := {}  # country id -> Array of region ids
	for rid in regions:
		var owner: String = (regions[rid] as Region).country_id
		if owner == "":
			if not allow_unowned:
				problems.append("region %s has no owner" % rid)
		elif not countries.has(owner):
			problems.append("region %s is owned by unknown country %s" % [rid, owner])
		else:
			if not owned.has(owner):
				owned[owner] = []
			owned[owner].append(rid)

	var players := 0
	for cid in countries:
		var country: Country = countries[cid]
		if country.id != cid:
			problems.append("key %s holds country %s" % [cid, country.id])
		var own_regions: Array = owned.get(cid, [])
		if own_regions.is_empty():
			problems.append("country %s has no regions" % cid)
		var index := {}
		for rid in country.regions:
			index[rid] = true
		var index_ok := index.size() == country.regions.size() and index.size() == own_regions.size()
		if index_ok:
			for rid in own_regions:
				if not index.has(rid):
					index_ok = false
		if not index_ok:
			problems.append("country %s: region list is out of sync with region owners" % cid)
		if country.capital_region == "" or not regions.has(country.capital_region) \
				or (regions[country.capital_region] as Region).country_id != cid:
			problems.append("country %s: capital %s is not its own region" % [cid, country.capital_region])
		if country.is_player_controlled:
			players += 1
	if players > 1:
		problems.append("%d countries are player controlled (max 1)" % players)
	return problems


## Cities (spec 4.87, 4.107): every city is in a real region, Region.cities lists exactly
## the cities of that region, buildings and queued orders are known and not duplicated.
## catalog: id -> Building.
static func check_cities(cities: Dictionary, regions: Dictionary, catalog: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var expected := {}  # region id -> Array of city ids
	for cid in cities:
		var city: City = cities[cid]
		if city.id != cid:
			problems.append("key %s holds city %s" % [cid, city.id])
		if not regions.has(city.region_id):
			problems.append("city %s is in unknown region %s" % [cid, city.region_id])
		else:
			if not expected.has(city.region_id):
				expected[city.region_id] = []
			expected[city.region_id].append(cid)
		var seen := {}
		for building_id in city.buildings:
			if seen.has(building_id):
				problems.append("city %s has %s twice" % [cid, building_id])
			elif not catalog.has(building_id):
				problems.append("city %s has unknown building %s" % [cid, building_id])
			seen[building_id] = true
		for order in city.queue:
			if not catalog.has(order.building_id):
				problems.append("city %s queues unknown building %s" % [cid, order.building_id])
			elif seen.has(order.building_id):
				problems.append("city %s builds %s that is already built or queued" % [cid, order.building_id])
			seen[order.building_id] = true
		if city.queue.size() > ProductionRules.MAX_QUEUE_SIZE:
			problems.append("city %s has %d orders (max %d)" % [cid, city.queue.size(), ProductionRules.MAX_QUEUE_SIZE])
	for rid in regions:
		var listed: Array = (regions[rid] as Region).cities.duplicate()
		var wanted: Array = (expected.get(rid, []) as Array).duplicate()
		listed.sort()
		wanted.sort()
		if listed != wanted:
			problems.append("region %s: city list is out of sync with the cities" % rid)
	return problems
