extends "res://scripts/game.gd"

# The playable flight-test scene opts into a clean arena without changing
# the classic game scene or its regression tests.
func _init() -> void:
	flight_test_mode = true
