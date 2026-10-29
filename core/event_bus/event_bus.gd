extends Node
## Autoload "EventBus".
## Decoupled publish/subscribe. Systems never call each other directly.
## Callbacks receive one argument: a Dictionary payload (treat as read-only).

var _subscribers: Dictionary = {}  # StringName -> Array[Callable]


func subscribe(event_name: StringName, callback: Callable) -> void:
	if not callback.is_valid():
		push_warning("EventBus.subscribe: invalid callable for '%s'" % event_name)
		return
	var list: Array = _subscribers.get(event_name, [])
	if callback in list:
		return
	list.append(callback)
	_subscribers[event_name] = list


func unsubscribe(event_name: StringName, callback: Callable) -> void:
	if not _subscribers.has(event_name):
		return
	var list: Array = _subscribers[event_name]
	list.erase(callback)
	if list.is_empty():
		_subscribers.erase(event_name)


## Calls every valid subscriber in subscription order.
## Subscribers added during emit are not called for the current event.
## Callables of freed objects are removed.
func emit(event_name: StringName, payload: Dictionary = {}) -> void:
	if not _subscribers.has(event_name):
		return
	var snapshot: Array = (_subscribers[event_name] as Array).duplicate()
	var has_dead := false
	for item in snapshot:
		var callback: Callable = item
		if callback.is_valid():
			callback.call(payload)
		else:
			has_dead = true
	if has_dead:
		_prune(event_name)


func get_subscriber_count(event_name: StringName) -> int:
	if not _subscribers.has(event_name):
		return 0
	return (_subscribers[event_name] as Array).size()


func clear() -> void:
	_subscribers.clear()


func _prune(event_name: StringName) -> void:
	if not _subscribers.has(event_name):
		return
	var alive: Array = []
	for item in (_subscribers[event_name] as Array):
		var callback: Callable = item
		if callback.is_valid():
			alive.append(callback)
	if alive.is_empty():
		_subscribers.erase(event_name)
	else:
		_subscribers[event_name] = alive
