extends CanvasLayer
## Army panel: the military of the player's country in the selected region.
## Recruit units (in a city), form an army from the free units, name a general.
## Reads WorldState only. Actions go through CommandBus. Which buttons are enabled
## comes from MilitaryRules, the same rules the commands use.

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _info: Label = $Panel/Margin/Box/Info
@onready var _buttons: VBoxContainer = $Panel/Margin/Box/Scroll/Buttons
@onready var _message: Label = $Panel/Margin/Box/Message

var _region_id: String = ""


func _ready() -> void:
	EventBus.subscribe(Events.REGION_SELECTED, _on_region_selected)
	EventBus.subscribe(Events.NEW_SEASON, _on_event)
	EventBus.subscribe(Events.COMMAND_EXECUTED, _on_event)
	WorldState.state_replaced.connect(_on_state_replaced)
	WorldState.player_country_changed.connect(_on_country_signal)
	WorldState.military_changed.connect(_refresh)
	WorldState.region_owner_changed.connect(_on_region_owner_changed)
	_refresh()


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.REGION_SELECTED, _on_region_selected)
	EventBus.unsubscribe(Events.NEW_SEASON, _on_event)
	EventBus.unsubscribe(Events.COMMAND_EXECUTED, _on_event)


func _on_region_selected(payload: Dictionary) -> void:
	_region_id = payload["region_id"]
	_message.text = ""
	_refresh()


func _on_event(_payload: Dictionary) -> void:
	_refresh()


func _on_state_replaced() -> void:
	_region_id = ""
	_message.text = ""
	_refresh()


func _on_country_signal(_country_id: String) -> void:
	_refresh()


func _on_region_owner_changed(_region_id_changed: String, _old_owner: String, _new_owner: String) -> void:
	_refresh()


func _refresh() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	var player := WorldState.get_player_country()
	if player == null or _region_id == "" or not WorldState.regions.has(_region_id):
		_panel.visible = false
		return
	_panel.visible = true
	var region: Region = WorldState.regions[_region_id]
	_title.text = "Military: %s" % _region_id
	_info.text = _describe(player, region)

	if not region.cities.is_empty():
		var city: City = WorldState.cities[region.cities[0]]
		var types := UnitCatalog.get_all()
		var type_ids: Array = types.keys()
		type_ids.sort()
		for type_id in type_ids:
			var unit_type: UnitType = types[type_id]
			var button := Button.new()
			button.text = "Recruit %s in %s: %s gold, %s manpower" % [
				unit_type.name, city.name, NumberFormat.thousands(int(unit_type.cost)),
				NumberFormat.thousands(unit_type.manpower)]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var problem := MilitaryRules.recruit_problem(WorldState, city.id, type_id, player.id)
			button.disabled = problem != ""
			button.tooltip_text = problem
			button.pressed.connect(_on_recruit_pressed.bind(city.id, type_id))
			_buttons.add_child(button)

	var free_here := MilitaryRules.free_units(WorldState, player.id, _region_id)
	if not free_here.is_empty():
		var chosen := free_here.slice(0, Army.MAX_UNITS)
		var form := Button.new()
		form.text = "Form an army from %d free units" % chosen.size()
		form.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var form_problem := MilitaryRules.army_problem(WorldState, _region_id, chosen, player.id)
		form.disabled = form_problem != ""
		form.tooltip_text = form_problem
		form.pressed.connect(_on_form_pressed.bind(chosen))
		_buttons.add_child(form)

	var free_generals := MilitaryRules.free_generals(WorldState, player.id)
	for army_id in WorldState.armies:
		var army: Army = WorldState.armies[army_id]
		if army.country_id != player.id or army.region_id != _region_id:
			continue
		for general_id in free_generals:
			var general: General = WorldState.generals[general_id]
			var button := Button.new()
			button.text = "Appoint %s to %s" % [general.name, army.name]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var problem := MilitaryRules.general_problem(WorldState, army_id, general_id, player.id)
			button.disabled = problem != ""
			button.tooltip_text = problem
			button.pressed.connect(_on_assign_pressed.bind(army_id, general_id))
			_buttons.add_child(button)


func _describe(player: Country, region: Region) -> String:
	var lines: Array[String] = []
	lines.append("Manpower: %s | Gold: %s" % [
		NumberFormat.thousands(int(player.manpower)), NumberFormat.thousands(int(player.treasury))])
	var free_here := MilitaryRules.free_units(WorldState, player.id, _region_id)
	lines.append("Free units here: %s" % _count_text(free_here))
	var any_army := false
	for army_id in WorldState.armies:
		var army: Army = WorldState.armies[army_id]
		if army.region_id != _region_id:
			continue
		any_army = true
		var leader := "no general"
		if army.general_id != "" and WorldState.generals.has(army.general_id):
			leader = (WorldState.generals[army.general_id] as General).name
		var owner_text := "" if army.country_id == player.id else " (foreign)"
		lines.append("%s%s: %d units, %s" % [army.name, owner_text, army.units.size(), leader])
	if not any_army:
		lines.append("No armies here")
	if region.cities.is_empty():
		lines.append("No city here: units cannot be recruited")
	return "\n".join(lines)


## "3 Infantry, 1 Cavalry" or "none".
func _count_text(unit_ids: Array) -> String:
	var counts := {}
	for unit_id in unit_ids:
		var type_id: String = (WorldState.units[unit_id] as Unit).type_id
		counts[type_id] = int(counts.get(type_id, 0)) + 1
	var parts: Array[String] = []
	var type_ids: Array = counts.keys()
	type_ids.sort()
	for type_id in type_ids:
		var unit_type := UnitCatalog.get_unit_type(type_id)
		parts.append("%d %s" % [counts[type_id], unit_type.name if unit_type != null else type_id])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _on_recruit_pressed(city_id: String, type_id: String) -> void:
	var player := WorldState.get_player_country()
	if player != null:
		_report(CommandBus.submit(RecruitUnitCommand.new(city_id, type_id, player.id)))


func _on_form_pressed(unit_ids: Array) -> void:
	var player := WorldState.get_player_country()
	if player != null:
		_report(CommandBus.submit(CreateArmyCommand.new(_region_id, unit_ids, "", player.id)))


func _on_assign_pressed(army_id: String, general_id: String) -> void:
	var player := WorldState.get_player_country()
	if player != null:
		_report(CommandBus.submit(AssignGeneralCommand.new(army_id, general_id, player.id)))


func _report(result: CommandResult) -> void:
	_message.text = "" if result.ok else result.reason
