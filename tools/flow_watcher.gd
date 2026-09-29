extends Node

## Helper for flow_test.gd.

const BUILDING := "res://scenes/building/bic_building.tscn"

var failures_so_far: int = 0
var expected_name: String = ""

func _ready() -> void:
	_wait_for_building()

func _wait_for_building() -> void:
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current and current.scene_file_path == BUILDING:
			await get_tree().process_frame
			_check(current)
			return
	print("  FAIL  the building never became the current scene")
	_finish(failures_so_far + 1)

func _check(building: Node) -> void:
	var failures := failures_so_far

	if GameState.player_name == expected_name:
		print("  ok    GameState.player_name survived the scene change (\"%s\")" % GameState.player_name)
	else:
		print("  FAIL  GameState.player_name is \"%s\", expected \"%s\"" % [GameState.player_name, expected_name])
		failures += 1

	var hud: Node = building.get_node_or_null("InteractHUD")
	if hud == null:
		print("  FAIL  the building has no InteractHUD")
		failures += 1
	else:
		var line: String = hud.activity_label.text
		if line.contains(expected_name):
			print("  ok    the building greets the player by name (\"%s\")" % line)
		else:
			print("  FAIL  HUD line \"%s\" does not contain \"%s\"" % [line, expected_name])
			failures += 1

	if building.get_node_or_null("Player") == null:
		print("  FAIL  the building has no Player")
		failures += 1
	else:
		print("  ok    player is present in the building")

	_finish(failures)

func _finish(failures: int) -> void:
	print("")
	if failures == 0:
		print("FLOW TEST PASSED")
	else:
		print("FLOW TEST FAILED (%d problem(s))" % failures)
	get_tree().quit(1 if failures > 0 else 0)
