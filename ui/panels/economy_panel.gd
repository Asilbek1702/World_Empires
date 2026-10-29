extends CanvasLayer
## Economy panel of the player's country: treasury and the forecast for the coming season.
## The forecast uses the current population. The real tick uses the population after
## growth, so the actual income is slightly higher.
## Refreshes on Events.NEW_SEASON and on WorldState changes (no polling).

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Margin/Box/Title
@onready var _treasury: Label = $Panel/Margin/Box/Treasury
@onready var _income: Label = $Panel/Margin/Box/Income
@onready var _expenses: Label = $Panel/Margin/Box/Expenses
@onready var _net: Label = $Panel/Margin/Box/Net
@onready var _production: Label = $Panel/Margin/Box/Production

const GOOD := Color(0.55, 0.9, 0.55)
const BAD := Color(1.0, 0.5, 0.5)


func _ready() -> void:
	EventBus.subscribe(Events.NEW_SEASON, _on_new_season)
	WorldState.state_replaced.connect(_refresh)
	WorldState.player_country_changed.connect(_on_player_country_changed)
	WorldState.region_owner_changed.connect(_on_region_owner_changed)
	_refresh()


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.NEW_SEASON, _on_new_season)


func _on_new_season(_payload: Dictionary) -> void:
	_refresh()


func _on_player_country_changed(_country_id: String) -> void:
	_refresh()


func _on_region_owner_changed(_region_id: String, _old_owner: String, _new_owner: String) -> void:
	_refresh()


func _refresh() -> void:
	var player := WorldState.get_player_country()
	_panel.visible = player != null
	if player == null:
		return
	var report := EconomyModel.country_report(player, WorldState.regions, WorldState.cities)
	var net := int(round(report.net_gold()))
	_title.text = "Economy: %s" % player.name
	_treasury.text = "Treasury: %s" % NumberFormat.thousands(int(round(player.treasury)))
	_income.text = "Income: %s / season" % NumberFormat.signed(int(round(report.gold_income())))
	var lines: Array[String] = ["Expenses: %s / season" % NumberFormat.signed(-int(round(report.expenses())))]
	for item in report.expense_items:
		lines.append("   %s: %s" % [item, NumberFormat.signed(-int(round(report.expense_items[item])))])
	_expenses.text = "\n".join(lines)
	_net.text = "Net: %s / season" % NumberFormat.signed(net)
	_net.add_theme_color_override("font_color", GOOD if net >= 0 else BAD)
	var production: Array[String] = ["Production per season:"]
	for type in [ResourceTypes.Type.FOOD, ResourceTypes.Type.INDUSTRY,
			ResourceTypes.Type.SCIENCE, ResourceTypes.Type.MANPOWER]:
		production.append("   %s: %s" % [
			ResourceTypes.display_name(type), NumberFormat.compact(int(round(report.get_output(type))))])
	_production.text = "\n".join(production)
