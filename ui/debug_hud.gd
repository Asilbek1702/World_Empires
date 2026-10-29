extends CanvasLayer
## Debug HUD: date, seed, season button, new game / save / load, EventBus and RNG checks.
## Temporary. Replaced by the real HUD in Iter 19.

const SAVE_PATH := "user://debug_save.json"

var _ping_count: int = 0
var _selected_region_id: String = ""

@onready var _date_label: Label = $Panel/DateLabel
@onready var _status_label: Label = $Panel/StatusLabel
@onready var _panel: Control = $Panel
@onready var _region_info: Label = $RegionInfo
@onready var _next_button: Button = $Panel/NextSeasonButton
@onready var _trace_check: CheckButton = $Panel/TraceCheck
@onready var _new_game_button: Button = $Panel/NewGameButton
@onready var _save_button: Button = $Panel/SaveButton
@onready var _load_button: Button = $Panel/LoadButton
@onready var _ping_button: Button = $Panel/PingButton
@onready var _cmd_valid_button: Button = $Panel/CmdValidButton
@onready var _cmd_invalid_button: Button = $Panel/CmdInvalidButton
@onready var _rng_button: Button = $Panel/RngButton


func _ready() -> void:
	_next_button.pressed.connect(_on_next_season_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_ping_button.pressed.connect(_on_ping_pressed)
	_cmd_valid_button.pressed.connect(_on_cmd_valid_pressed)
	_cmd_invalid_button.pressed.connect(_on_cmd_invalid_pressed)
	_rng_button.pressed.connect(_on_rng_pressed)
	_trace_check.toggled.connect(_on_trace_toggled)
	EventBus.subscribe(Events.NEW_SEASON, _on_new_season)
	WorldState.state_replaced.connect(_on_state_replaced)
	WorldState.player_country_changed.connect(_on_player_country_changed)
	WorldState.building_completed.connect(_on_building_completed)
	EventBus.subscribe(Events.TEST_PING, _on_test_ping)
	EventBus.subscribe(Events.COMMAND_EXECUTED, _on_command_executed)
	EventBus.subscribe(Events.COMMAND_REJECTED, _on_command_rejected)
	EventBus.subscribe(Events.REGION_SELECTED, _on_region_selected)
	_refresh()


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.TEST_PING, _on_test_ping)
	EventBus.unsubscribe(Events.NEW_SEASON, _on_new_season)
	EventBus.unsubscribe(Events.COMMAND_EXECUTED, _on_command_executed)
	EventBus.unsubscribe(Events.COMMAND_REJECTED, _on_command_rejected)
	EventBus.unsubscribe(Events.REGION_SELECTED, _on_region_selected)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_F1:
		_panel.visible = not _panel.visible


func _on_next_season_pressed() -> void:
	SeasonTickManager.advance_season()


func _on_new_season(_payload: Dictionary) -> void:
	_refresh()
	_show_region()


func _on_building_completed(city_id: String, building_id: String) -> void:
	var city: City = WorldState.cities[city_id]
	var building := BuildingCatalog.get_building(building_id)
	_set_status("%s finished in %s" % [building.name if building != null else building_id, city.name])


func _on_trace_toggled(pressed: bool) -> void:
	SeasonTickManager.trace = pressed
	if pressed:
		print("[Tick] pipeline:")
		for line in SeasonTickManager.describe_pipeline():
			print("[Tick]   %s" % line)


func _on_state_replaced() -> void:
	_refresh()


func _on_player_country_changed(_country_id: String) -> void:
	_refresh()


func _on_new_game_pressed() -> void:
	GameRNG.seed_from_time()
	var error := WorldBuilder.start_new_game(WorldState, GameRNG.get_seed(), null, GameRNG)
	if error == OK:
		_set_status("New game. Seed %d, %d regions" % [WorldState.rng_seed, WorldState.regions.size()])
	else:
		_set_status("New game FAILED: %s" % WorldBuilder.last_error)


func _on_save_pressed() -> void:
	var error := SaveSystem.save_to_json(SAVE_PATH, WorldState, GameRNG)
	if error == OK:
		_set_status("Saved: %s" % ProjectSettings.globalize_path(SAVE_PATH))
	else:
		_set_status("Save FAILED: %s" % SaveSystem.last_error)


func _on_load_pressed() -> void:
	var error := SaveSystem.load_from_json(SAVE_PATH, WorldState, GameRNG)
	if error == OK:
		_set_status("Loaded. %s, seed %d" % [WorldState.game_date, WorldState.rng_seed])
	else:
		_set_status("Load FAILED: %s" % SaveSystem.last_error)


func _on_cmd_valid_pressed() -> void:
	CommandBus.submit(DebugSetSeedCommand.new(777))


func _on_cmd_invalid_pressed() -> void:
	CommandBus.submit(DebugSetSeedCommand.new(-1))


func _on_command_executed(payload: Dictionary) -> void:
	_set_status("Command OK: %s" % payload["command_name"])
	_refresh()


func _on_command_rejected(payload: Dictionary) -> void:
	_set_status("Command REJECTED: %s (%s)" % [payload["command_name"], payload["reason"]])


func _on_region_selected(payload: Dictionary) -> void:
	_selected_region_id = payload["region_id"]
	_show_region()
	if _selected_region_id != "":
		print("[Map] %s" % _region_info.text.replace("\n", " | "))


func _show_region() -> void:
	if _selected_region_id == "" or not WorldState.regions.has(_selected_region_id):
		_region_info.text = "Region: - (click a region)"
		return
	var region: Region = WorldState.regions[_selected_region_id]
	var owner_text := "-"
	if WorldState.countries.has(region.country_id):
		owner_text = (WorldState.countries[region.country_id] as Country).name
	var city_text := ""
	if not region.cities.is_empty():
		city_text = " | city %s" % (WorldState.cities[region.cities[0]] as City).name
	_region_info.text = "%s | %s | owner %s%s | pop %s / cap %s\nNeighbors (%d): %s" % [
		region.id, Region.TERRAIN_NAMES[region.terrain], owner_text, city_text,
		NumberFormat.thousands(region.population),
		NumberFormat.thousands(PopulationConfig.capacity(region)),
		region.neighbors.size(), ", ".join(region.neighbors)]


func _on_ping_pressed() -> void:
	_ping_count += 1
	EventBus.emit(Events.TEST_PING, {"count": _ping_count})


func _on_test_ping(payload: Dictionary) -> void:
	print("[EventBus] test_ping received: %s" % str(payload))


func _on_rng_pressed() -> void:
	var previous_seed := GameRNG.get_seed()
	var previous_state := GameRNG.get_state()
	var first := _draw_sequence(12345)
	var second := _draw_sequence(12345)
	print("[RNG] seed 12345, run 1: %s" % str(first))
	print("[RNG] seed 12345, run 2: %s" % str(second))
	print("[RNG] deterministic: %s" % str(first == second))
	# Leave the campaign RNG exactly as it was.
	GameRNG.set_seed(previous_seed)
	GameRNG.set_state(previous_state)


func _draw_sequence(seed_value: int) -> Array[int]:
	GameRNG.set_seed(seed_value)
	var out: Array[int] = []
	for i in 5:
		out.append(GameRNG.range_int(1, 100))
	return out


func _set_status(text: String) -> void:
	print("[HUD] %s" % text)
	_status_label.text = text


func _refresh() -> void:
	var date: GameDate = WorldState.game_date
	var player := WorldState.get_player_country()
	_next_button.disabled = player == null  # the season starts after a country is chosen
	var player_text := "no country chosen"
	if player != null:
		player_text = "%s, pop %s" % [
			player.name, NumberFormat.compact(PopulationStats.country_total(player, WorldState.regions))]
	_date_label.text = "%s | turn %d | seed %d | %s" % [
		date, date.turn_number, WorldState.rng_seed, player_text]
