class_name JsonNumbers
extends RefCounted
## JSON has one number type, so 2 comes back as 2.0 and Dictionary == breaks.
## canonical() turns every whole float into an int, recursively (returns a copy).
## Apply it to free-form dictionaries (resources, technology levels) both when
## saving and when loading, so a value has exactly one form.


static func canonical(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			if is_finite(number) and number == floorf(number) and absf(number) < 9.0e15:
				return int(number)
			return value
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[key] = canonical(value[key])
			return out
		TYPE_ARRAY:
			var items := []
			for item in value:
				items.append(canonical(item))
			return items
	return value
