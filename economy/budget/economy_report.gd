class_name EconomyReport
extends RefCounted
## One country's economy for one season: what its regions produce and what the state pays.

## ResourceTypes.Type (int) -> float produced per season.
var output: Dictionary = {}
## Expense name -> gold per season. Army, buildings etc. add items in later iterations.
var expense_items: Dictionary = {}


func get_output(type: int) -> float:
	return float(output.get(type, 0.0))


func gold_income() -> float:
	return get_output(ResourceTypes.Type.GOLD)


func expenses() -> float:
	var total := 0.0
	for name in expense_items:
		total += float(expense_items[name])
	return total


func net_gold() -> float:
	return gold_income() - expenses()
