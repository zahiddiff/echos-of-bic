extends Node

## Headless test of the New Game flow: name entry -> GameState autoload -> building scene.
## Run: godot --headless --path <project> res://tools/flow_test.tscn

const TEST_NAME := "Zahidul"

var _failures := 0

func _ready() -> void:
	_run()

func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)

func _ok(message: String) -> void:
	print("  ok    %s" % message)

func _expect(condition: bool, message: String) -> void:
	if condition:
		_ok(message)
	else:
		_fail(message)

func _run() -> void:
	print("Flow test")

	print("\n GameState")
	GameState.reset()
	var emitted: Array[String] = []
	GameState.player_name_changed.connect(func(value: String) -> void: emitted.append(value))

	GameState.set_player_name("   Zahidul   ")
	_expect(GameState.player_name == TEST_NAME,
		"whitespace is trimmed (got \"%s\")" % GameState.player_name)
	_expect(emitted.size() == 1, "player_name_changed fired once (got %d)" % emitted.size())
	GameState.set_player_name(TEST_NAME)
	_expect(emitted.size() == 1, "setting the same name again does not re-emit")
	GameState.reset()
	_expect(not GameState.has_player_name(), "reset() clears the name")

	print("\n Name entry validation")
	var entry: Control = load("res://scenes/ui/name_entry.tscn").instantiate()
	add_child(entry)
	await get_tree().process_frame

	entry.name_field.text = "    "
	entry._submit()
	_expect(entry.error_label.visible, "a blank name shows the error line")
	_expect(not GameState.has_player_name(), "a blank name does not reach GameState")

	entry.name_field.text = "Zed"
	entry._on_text_changed("Zed")
	_expect(not entry.error_label.visible, "typing clears the error line")

	print("\n Transition into the building")
	# Parked under /root so it outlives the scene swap that frees this node.
	var watcher := Node.new()
	watcher.name = "FlowWatcher"
	watcher.set_script(load("res://tools/flow_watcher.gd"))
	watcher.set("failures_so_far", _failures)
	watcher.set("expected_name", TEST_NAME)
	get_tree().root.add_child(watcher)

	entry.name_field.text = TEST_NAME
	entry._submit()
	# From here the watcher owns the result — this scene is about to be freed.
