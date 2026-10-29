class_name Events
extends RefCounted
## Event name registry. One constant per event, no raw strings in game code.
## Iter 2: test event only. Real events are added with their systems.

const TEST_PING := &"test_ping"
const COMMAND_EXECUTED := &"command_executed"
const COMMAND_REJECTED := &"command_rejected"
const REGION_SELECTED := &"region_selected"
const COUNTRY_PREVIEWED := &"country_previewed"
## Published once per season after all phases ran and the date advanced.
## Payload: date (GameDate copy), year, season (int), season_name, turn_number.
const NEW_SEASON := &"new_season"
