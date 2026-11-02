extends CanvasLayer
## Research panel of the player's country: current research, science, technology list.
## Reads WorldState only. Choosing a technology goes through CommandBus (StartResearchCommand).
## Which buttons are enabled comes from ResearchRules, the same rules the command uses.
## Refreshes on Events.NEW_SEASON and on WorldState signals (no polling).

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _info: Label = $Panel/Margin/Box/Info
@onready var _buttons: VBoxContainer = $Panel/Margin/Box/Scroll/Buttons
@onready var _message: Label = $Panel/Margin/Box/Message


func _ready() -> void:
	EventBus.subscribe(Events.NEW_SEASON, _on_event)
	EventBus.subscribe(Events.COMMAND_EXECUTED, _on_event)
	WorldState.state_replaced.connect(_on_state_replaced)
	WorldState.player_country_changed.connect(_on_country_signal)
	WorldState.research_changed.connect(_on_country_signal)
	WorldState.technology_researched.connect(_on_technology_researched)
	WorldState.region_owner_changed.connect(_on_region_owner_changed)
	_refresh()


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.NEW_SEASON, _on_event)
	EventBus.unsubscribe(Events.COMMAND_EXECUTED, _on_event)


func _on_event(_payload: Dictionary) -> void:
	_refresh()


func _on_state_replaced() -> void:
	_message.text = ""
	_refresh()


func _on_country_signal(_country_id: String) -> void:
	_refresh()


func _on_technology_researched(_country_id: String, _technology_id: String) -> void:
	_refresh()


func _on_region_owner_changed(_region_id: String, _old_owner: String, _new_owner: String) -> void:
	_refresh()


func _refresh() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	var player := WorldState.get_player_country()
	_panel.visible = player != null
	if player == null:
		return
	var catalog := TechnologyCatalog.get_all()
	var report := EconomyModel.country_report(player, WorldState.regions, WorldState.cities)
	var science := report.get_output(ResourceTypes.Type.SCIENCE)
	_title.text = "Research: %s" % player.name
	_info.text = _describe(player, catalog, science)

	var ids: Array = catalog.keys()
	ids.sort()
	for technology_id in ids:
		if player.researched_technologies.has(technology_id):
			continue
		var tech: Technology = catalog[technology_id]
		var button := Button.new()
		var marker := "> " if player.current_research == technology_id else ""
		button.text = "%s%s: %s science%s" % [
			marker, tech.name, NumberFormat.thousands(tech.cost), _effect_text(tech)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var problem := ResearchRules.start_problem(WorldState, player.id, technology_id)
		button.disabled = problem != ""
		button.tooltip_text = problem
		if problem == "" and player.current_research != "":
			button.tooltip_text = "Switching drops the progress of the current research"
		button.pressed.connect(_on_start_pressed.bind(technology_id))
		_buttons.add_child(button)


func _describe(player: Country, catalog: Dictionary, science: float) -> String:
	var lines: Array[String] = []
	lines.append("Science: %s / season" % NumberFormat.compact(int(round(science))))
	var current: Technology = catalog.get(player.current_research)
	if current == null:
		lines.append("Idle: science is wasted. Pick a technology.")
	else:
		var left := TechnologyModel.seasons_left(player.research_progress, current.cost, science)
		var eta := "%d seasons left" % left if left >= 0 else "no science"
		lines.append("Now: %s %s / %s, %s" % [
			current.name, NumberFormat.thousands(int(player.research_progress)),
			NumberFormat.thousands(current.cost), eta])
	var known: Array[String] = []
	for technology_id in player.researched_technologies:
		var tech: Technology = catalog.get(technology_id)
		known.append(tech.name if tech != null else technology_id)
	lines.append("Known: %s" % (", ".join(known) if not known.is_empty() else "none"))
	return "\n".join(lines)


func _effect_text(tech: Technology) -> String:
	var parts: Array[String] = []
	for type in tech.output_modifiers:
		parts.append("%+d%% %s" % [
			int(round(float(tech.output_modifiers[type]) * 100.0)), ResourceTypes.display_name(type)])
	return "  (%s)" % ", ".join(parts) if not parts.is_empty() else ""


func _on_start_pressed(technology_id: String) -> void:
	var player := WorldState.get_player_country()
	if player == null:
		return
	var result := CommandBus.submit(StartResearchCommand.new(technology_id, player.id))
	_message.text = "" if result.ok else result.reason
