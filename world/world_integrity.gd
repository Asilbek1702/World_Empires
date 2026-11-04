class_name WorldIntegrity
extends RefCounted
## Consistency rules of the territory model (spec 4.87, 4.107).
## Returns a list of human-readable problems. Empty list = consistent.


static func check(state: Node, allow_unowned: bool = false) -> Array[String]:
	var problems := check_territory(state.countries, state.regions, allow_unowned)
	problems.append_array(check_cities(state.cities, state.regions, BuildingCatalog.get_all()))
	problems.append_array(check_technologies(state.countries, TechnologyCatalog.get_all()))
	problems.append_array(check_military(state.countries, state.regions, state.units,
			state.armies, state.generals, UnitCatalog.get_all()))
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


## Technologies: researched ones are known, unique and have their requirements researched;
## the current research is known, not yet researched, startable, and its progress is below the cost;
## progress without a current research must be 0. catalog: id -> Technology.
static func check_technologies(countries: Dictionary, catalog: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for cid in countries:
		var country: Country = countries[cid]
		var known := {}
		for tech_id in country.researched_technologies:
			if known.has(tech_id):
				problems.append("country %s has %s twice" % [cid, tech_id])
			elif not catalog.has(tech_id):
				problems.append("country %s knows unknown technology %s" % [cid, tech_id])
			known[tech_id] = true
		for tech_id in country.researched_technologies:
			if not catalog.has(tech_id):
				continue
			for required in (catalog[tech_id] as Technology).requires:
				if not known.has(required):
					problems.append("country %s has %s without its requirement %s" % [cid, tech_id, required])
		if country.research_progress < 0.0:
			problems.append("country %s has negative research progress" % cid)
		if country.current_research == "":
			if country.research_progress != 0.0:
				problems.append("country %s has research progress without a research" % cid)
		elif not catalog.has(country.current_research):
			problems.append("country %s researches unknown technology %s" % [cid, country.current_research])
		elif known.has(country.current_research):
			problems.append("country %s researches %s again" % [cid, country.current_research])
		else:
			var tech: Technology = catalog[country.current_research]
			for required in tech.requires:
				if not known.has(required):
					problems.append("country %s researches %s without %s" % [cid, tech.id, required])
			if country.research_progress >= float(tech.cost):
				problems.append("country %s has finished %s but it is not in the list" % [cid, tech.id])
	return problems


## Military (Iter 12): units are of a known type and stand in a real region of a real country;
## an army is not empty, has at most MAX_UNITS units of its own country standing in its region,
## and no unit is in two armies; a general and the army he leads point at each other.
## unit_types: id -> UnitType.
static func check_military(countries: Dictionary, regions: Dictionary, units: Dictionary,
		armies: Dictionary, generals: Dictionary, unit_types: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for uid in units:
		var unit: Unit = units[uid]
		if unit.id != uid:
			problems.append("key %s holds unit %s" % [uid, unit.id])
		if not unit_types.has(unit.type_id):
			problems.append("unit %s has unknown type %s" % [uid, unit.type_id])
		if not countries.has(unit.country_id):
			problems.append("unit %s belongs to unknown country %s" % [uid, unit.country_id])
		if not regions.has(unit.region_id):
			problems.append("unit %s stands in unknown region %s" % [uid, unit.region_id])
	var in_army := {}  # unit id -> army id
	for aid in armies:
		var army: Army = armies[aid]
		if army.id != aid:
			problems.append("key %s holds army %s" % [aid, army.id])
		if not countries.has(army.country_id):
			problems.append("army %s belongs to unknown country %s" % [aid, army.country_id])
		if not regions.has(army.region_id):
			problems.append("army %s stands in unknown region %s" % [aid, army.region_id])
		if army.units.is_empty() or army.units.size() > Army.MAX_UNITS:
			problems.append("army %s has %d units (1..%d allowed)" % [aid, army.units.size(), Army.MAX_UNITS])
		for uid in army.units:
			if not units.has(uid):
				problems.append("army %s lists unknown unit %s" % [aid, uid])
				continue
			if in_army.has(uid):
				problems.append("unit %s is in armies %s and %s" % [uid, in_army[uid], aid])
			in_army[uid] = aid
			var member: Unit = units[uid]
			if member.country_id != army.country_id:
				problems.append("unit %s is not of the country of army %s" % [uid, aid])
			if member.region_id != army.region_id:
				problems.append("unit %s is not in the region of army %s" % [uid, aid])
		if army.general_id != "":
			if not generals.has(army.general_id):
				problems.append("army %s has unknown general %s" % [aid, army.general_id])
			else:
				var leader: General = generals[army.general_id]
				if leader.army_id != aid:
					problems.append("army %s and general %s do not point at each other" % [aid, leader.id])
				if leader.country_id != army.country_id:
					problems.append("general %s leads an army of another country" % leader.id)
	for gid in generals:
		var general: General = generals[gid]
		if general.id != gid:
			problems.append("key %s holds general %s" % [gid, general.id])
		if not countries.has(general.country_id):
			problems.append("general %s belongs to unknown country %s" % [gid, general.country_id])
		if general.army_id != "":
			if not armies.has(general.army_id):
				problems.append("general %s leads unknown army %s" % [gid, general.army_id])
			elif (armies[general.army_id] as Army).general_id != gid:
				problems.append("general %s and army %s do not point at each other" % [gid, general.army_id])
	return problems
