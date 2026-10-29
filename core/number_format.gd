class_name NumberFormat
extends RefCounted
## Number to text helpers for the UI.


## 1234567 -> "1,234,567"
static func thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


## 9_650_000 -> "9.7M", 412_300 -> "412K", 950 -> "950"
static func compact(value: int) -> String:
	var size := absi(value)
	var sign_text := "-" if value < 0 else ""
	if size >= 1_000_000:
		return "%s%.1fM" % [sign_text, size / 1_000_000.0]
	if size >= 10_000:
		return "%s%dK" % [sign_text, int(round(size / 1000.0))]
	if size >= 1_000:
		return "%s%.1fK" % [sign_text, size / 1000.0]
	return "%s%d" % [sign_text, size]


## 1750 -> "+1,750", -300 -> "-300", 0 -> "0"
static func signed(value: int) -> String:
	if value > 0:
		return "+" + thousands(value)
	return thousands(value)
