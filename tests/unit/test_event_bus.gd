extends "res://tests/test_base.gd"

const BusScript := preload("res://core/event_bus/event_bus.gd")
const EVT := &"evt"


class Receiver extends Object:
	var received: Array = []

	func on_event(payload: Dictionary) -> void:
		received.append(payload)


func _init() -> void:
	print("test_event_bus")
	_test_payload_delivered()
	_test_subscription_order()
	_test_unsubscribe()
	_test_duplicate_subscribe_ignored()
	_test_emit_without_subscribers()
	_test_subscribe_during_emit()
	_test_freed_receiver_pruned()
	_test_events_are_separate()
	finish()


func _test_payload_delivered() -> void:
	var bus = BusScript.new()
	var got: Array = []
	bus.subscribe(EVT, func(p: Dictionary): got.append(p))
	bus.emit(EVT, {"x": 5})
	check(got.size() == 1 and got[0]["x"] == 5, "subscriber receives payload")
	bus.free()


func _test_subscription_order() -> void:
	var bus = BusScript.new()
	var order: Array = []
	bus.subscribe(EVT, func(_p): order.append("A"))
	bus.subscribe(EVT, func(_p): order.append("B"))
	bus.emit(EVT)
	check(order == ["A", "B"], "subscribers called in subscription order")
	bus.free()


func _test_unsubscribe() -> void:
	var bus = BusScript.new()
	var r := Receiver.new()
	bus.subscribe(EVT, r.on_event)
	bus.emit(EVT, {"n": 1})
	bus.unsubscribe(EVT, r.on_event)
	bus.emit(EVT, {"n": 2})
	check(r.received.size() == 1, "no delivery after unsubscribe")
	check(bus.get_subscriber_count(EVT) == 0, "subscriber count is 0 after unsubscribe")
	bus.unsubscribe(&"never_used", r.on_event)
	check(true, "unsubscribe of unknown event does not fail")
	r.free()
	bus.free()


func _test_duplicate_subscribe_ignored() -> void:
	var bus = BusScript.new()
	var r := Receiver.new()
	bus.subscribe(EVT, r.on_event)
	bus.subscribe(EVT, r.on_event)
	bus.emit(EVT)
	check(r.received.size() == 1, "duplicate subscription delivers once")
	check(bus.get_subscriber_count(EVT) == 1, "duplicate subscription counted once")
	r.free()
	bus.free()


func _test_emit_without_subscribers() -> void:
	var bus = BusScript.new()
	bus.emit(&"nobody_listens", {"a": 1})
	check(bus.get_subscriber_count(&"nobody_listens") == 0, "emit without subscribers is safe")
	bus.free()


func _test_subscribe_during_emit() -> void:
	var bus = BusScript.new()
	var late_calls: Array = []
	var late := func(_p): late_calls.append(1)
	bus.subscribe(EVT, func(_p): bus.subscribe(EVT, late))
	bus.emit(EVT)
	check(late_calls.is_empty(), "subscriber added during emit is not called in that emit")
	bus.emit(EVT)
	check(late_calls.size() == 1, "subscriber added during emit is called next emit")
	bus.free()


func _test_freed_receiver_pruned() -> void:
	var bus = BusScript.new()
	var alive := Receiver.new()
	var dead := Receiver.new()
	bus.subscribe(EVT, dead.on_event)
	bus.subscribe(EVT, alive.on_event)
	dead.free()
	bus.emit(EVT, {"k": 1})
	check(alive.received.size() == 1, "live subscriber still called")
	check(bus.get_subscriber_count(EVT) == 1, "freed receiver pruned")
	alive.free()
	bus.free()


func _test_events_are_separate() -> void:
	var bus = BusScript.new()
	var a_calls: Array = []
	var b_calls: Array = []
	bus.subscribe(&"a", func(_p): a_calls.append(1))
	bus.subscribe(&"b", func(_p): b_calls.append(1))
	bus.emit(&"a")
	check(a_calls.size() == 1 and b_calls.is_empty(), "events do not leak between names")
	bus.free()
