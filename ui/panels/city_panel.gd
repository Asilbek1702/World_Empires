extends CanvasLayer
## City panel: shows the city of the selected region and lets the player order buildings.
## Reads WorldState only. Orders go through CommandBus (BuildBuildingCommand).
## Which buttons are enabled comes from ProductionRules, the same rules the command uses.

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _info: Label = $Panel/Margin/Box/Info
@onready var _buttons: VBoxContainer = $Panel/Margin/Box/Buttons
@onready var _message: Label = $Panel/Margin/Box/Message

var _city_id: String = ""


func _ready() -> void:
	EventBus.subscribe(Events.REGION_SELECTED, _on_region_selected)
	EventBus.subscribe(Events.NEW_SEASON, _on_event)
	EventBus.subscribe(Events.COMMAND_EXECUTED, _on_event)
	WorldState.state_replaced.connect(_on_state_replaced)
	WorldState.city_changed.connect(_on_city_changed)
	WorldState.player_country_changed.connect(_on_player_country_changed)
	WorldState.region_owner_changed.connect(_on_region_owner_changed)
	_refresh()


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.REGION_SELECTED, _on_region_selected)
	EventBus.unsubscribe(Events.NEW_SEASON, _on_event)
	EventBus.unsubscribe(Events.COMMAND_EXECUTED, _on_event)


func _on_region_selected(payload: Dictionary) -> void:
	_city_id = ""
	_message.text = ""
	var region_id: String = payload["region_id"]
	if WorldState.regions.has(region_id):
		var region: Region = WorldState.regions[region_id]
		if not region.cities.is_empty():
			_city_id = region.cities[0]
	_refresh()


func _on_event(_payload: Dictionary) -> void:
	_refresh()


func _on_state_replaced() -> void:
	_city_id = ""
	_message.text = ""
	_refresh()


func _on_city_changed(_id: String) -> void:
	_refresh()


func _on_player_country_changed(_id: String) -> void:
	_refresh()


func _on_region_owner_changed(_region_id: String, _old_owner: String, _new_owner: String) -> void:
	_refresh()


func _refresh() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	if _city_id == "" or not WorldState.cities.has(_city_id):
		_panel.visible = false
		return
	_panel.visible = true
	var city: City = WorldState.cities[_city_id]
	var region: Region = WorldState.regions[city.region_id]
	var owner_name := "nobody"
	if WorldState.countries.has(region.country_id):
		owner_name = (WorldState.countries[region.country_id] as Country).name
	_title.text = "%s (%s), %s" % [city.name, city.level_name(), owner_name]
	_info.text = _describe(city)

	var player := WorldState.get_player_country()
	var catalog := BuildingCatalog.get_all()
	var ids: Array = catalog.keys()
	ids.sort()
	for building_id in ids:
		var building: Building = catalog[building_id]
		var button := Button.new()
		button.text = "Build %s: %s gold, %d seasons%s" % [
			building.name, NumberFormat.thousands(int(building.cost)),
			building.build_seasons, _gain_text(region, building)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var problem := "Choose a country first"
		if player != null:
			problem = ProductionRules.build_problem(WorldState, _city_id, building_id, player.id)
		button.disabled = problem != ""
		button.tooltip_text = problem
		button.pressed.connect(_on_build_pressed.bind(building_id))
		_buttons.add_child(button)


func _describe(city: City) -> String:
	var lines: Array[String] = []
	var names: Array[String] = []
	for building_id in city.buildings:
		var building := BuildingCatalog.get_building(building_id)
		names.append(building.name if building != null else building_id)
	lines.append("Buildings: %s" % (", ".join(names) if not names.is_empty() else "none"))
	if city.queue.is_empty():
		lines.append("Construction: idle")
	else:
		for order in city.queue:
			var building := BuildingCatalog.get_building(order.building_id)
			lines.append("Construction: %s %d/%d seasons" % [
				building.name if building != null else order.building_id,
				order.seasons_done, order.seasons_total])
	return "\n".join(lines)


func _gain_text(region: Region, building: Building) -> String:
	var parts: Array[String] = []
	var gain := EconomyModel.building_gain(region, building)
	for type in gain:
		parts.append("+%s %s" % [NumberFormat.compact(int(round(gain[type]))), ResourceTypes.display_name(type)])
	return "  (%s per season)" % ", ".join(parts) if not parts.is_empty() else ""


func _on_build_pressed(building_id: String) -> void:
	var player := WorldState.get_player_country()
	if player == null:
		return
	var result := CommandBus.submit(BuildBuildingCommand.new(_city_id, building_id, player.id))
	_message.text = "" if result.ok else result.reason
