class_name GameSystems
extends RefCounted
## The list of game systems. Add one line per new system.
## The tick phase of each system decides when it runs, so line order does not matter
## (except between systems of the same phase).


static func register_all(manager: Node) -> void:
	manager.register_system(PopulationSystem.new())
	manager.register_system(ProductionSystem.new())
	manager.register_system(EconomySystem.new())
	manager.register_system(ResearchSystem.new())
