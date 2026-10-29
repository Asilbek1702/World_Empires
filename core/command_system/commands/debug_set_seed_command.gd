class_name DebugSetSeedCommand
extends Command
## Debug only. Sets WorldState.rng_seed (does NOT reseed GameRNG).
## The simplest real mutation, used to prove the pipeline end to end.

var new_seed: int = 0


func _init(p_seed: int = 0, p_source_country: String = "") -> void:
	new_seed = p_seed
	source_country = p_source_country


func get_command_name() -> String:
	return "DebugSetSeed"


func validate(_state) -> bool:
	if new_seed < 0:
		return _reject("Seed must not be negative")
	return true


func execute(state) -> CommandResult:
	state.rng_seed = new_seed
	return CommandResult.success({"rng_seed": new_seed})
