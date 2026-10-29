extends "res://tests/test_base.gd"


func _init() -> void:
	print("test_number_format")
	check(NumberFormat.thousands(0) == "0", "thousands: 0")
	check(NumberFormat.thousands(999) == "999", "thousands: 999")
	check(NumberFormat.thousands(1000) == "1,000", "thousands: 1000")
	check(NumberFormat.thousands(1234567) == "1,234,567", "thousands: 1234567")
	check(NumberFormat.thousands(100000) == "100,000", "thousands: 100000")
	check(NumberFormat.thousands(-1234) == "-1,234", "thousands: negative")
	check(NumberFormat.compact(0) == "0", "compact: 0")
	check(NumberFormat.compact(950) == "950", "compact: 950")
	check(NumberFormat.compact(1500) == "1.5K", "compact: 1500")
	check(NumberFormat.compact(412300) == "412K", "compact: 412300")
	check(NumberFormat.compact(9650000) == "9.7M", "compact: 9650000")
	check(NumberFormat.compact(-2500000) == "-2.5M", "compact: negative")
	check(NumberFormat.signed(1750) == "+1,750", "signed: positive")
	check(NumberFormat.signed(-300) == "-300", "signed: negative")
	check(NumberFormat.signed(0) == "0", "signed: zero")
	finish()
