extends CanvasLayer
## "Choose your country" panel. Visible while a world with countries exists
## but no player country has been chosen. Clicking a country previews it on the map;
## Start sends SelectPlayerCountryCommand through the CommandBus.

@onready var _list: VBoxContainer = $Panel/Margin/Box/List
@onready var _start_button: Button = $Panel/Margin/Box/StartButton
@onready var _message: Label = $Panel/Margin/Box/Message
@onready var _panel: Control = $Panel

var _group := ButtonGroup.new()
var _selected_id: String = ""


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	WorldState.state_replaced.connect(_refresh)
	WorldState.player_country_changed.connect(_on_player_country_changed)
	_refresh()


func _on_player_country_changed(_country_id: String) -> void:
	_refresh()


func _refresh() -> void:
	var needs_choice := not WorldState.countries.is_empty() and WorldState.get_player_country() == null
	_panel.visible = needs_choice
	_selected_id = ""
	_start_button.disabled = true
	_message.text = ""
	for child in _list.get_children():
		child.queue_free()
	if not needs_choice:
		EventBus.emit(Events.COUNTRY_PREVIEWED, {"country_id": ""})
		return
	EventBus.emit(Events.COUNTRY_PREVIEWED, {"country_id": ""})
	var ids: Array = WorldState.countries.keys()
	ids.sort()
	for id in ids:
		_list.add_child(_make_row(WorldState.countries[id] as Country))


func _make_row(country: Country) -> Control:
	var row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = country.color
	swatch.custom_minimum_size = Vector2(22, 22)
	row.add_child(swatch)
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "%s  (%d regions)" % [country.name, country.regions.size()]
	button.toggled.connect(_on_country_toggled.bind(country.id))
	row.add_child(button)
	return row


func _on_country_toggled(pressed: bool, country_id: String) -> void:
	if not pressed:
		return
	_selected_id = country_id
	_start_button.disabled = false
	EventBus.emit(Events.COUNTRY_PREVIEWED, {"country_id": country_id})


func _on_start_pressed() -> void:
	var result := CommandBus.submit(SelectPlayerCountryCommand.new(_selected_id))
	if not result.ok:
		_message.text = result.reason
