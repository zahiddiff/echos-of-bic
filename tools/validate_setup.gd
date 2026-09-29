extends SceneTree

## Headless self-check for the Week 1-2 foundation.
## Run: godot --headless --path <project> --script res://tools/validate_setup.gd

const REQUIRED_ACTIONS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"interact": KEY_E,
	"ui_cancel": KEY_ESCAPE,
}

const REQUIRED_PLAYER_PATHS := [
	"CollisionShape3D",
	"Head",
	"Head/Camera3D",
	"Head/Camera3D/InteractRay",
]

var _failures := 0

func _init() -> void:
	_check_input_map()
	_check_player_scene()
	_check_test_scene()

	if _failures == 0:
		print("\nVALIDATION PASSED")
	else:
		print("\nVALIDATION FAILED (%d problem(s))" % _failures)
	quit(1 if _failures > 0 else 0)

func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)

func _ok(message: String) -> void:
	print("  ok    %s" % message)

func _check_input_map() -> void:
	print("Input Map")
	for action: String in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			_fail("%s is missing" % action)
			continue
		var wanted: int = REQUIRED_ACTIONS[action]
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				if code == wanted:
					found = true
		if found:
			_ok("%s -> %s" % [action, OS.get_keycode_string(wanted)])
		else:
			_fail("%s exists but is not bound to %s" % [action, OS.get_keycode_string(wanted)])

func _check_player_scene() -> void:
	print("Player scene")
	var packed: PackedScene = load("res://scenes/player/player.tscn")
	if packed == null:
		_fail("res://scenes/player/player.tscn did not load")
		return
	var player: Node = packed.instantiate()
	if not (player is CharacterBody3D):
		_fail("root is %s, expected CharacterBody3D" % player.get_class())
	else:
		_ok("root is CharacterBody3D")
	if player.get_script() == null:
		_fail("no script on the player root")
	else:
		_ok("player_controller.gd attached")
	for path: String in REQUIRED_PLAYER_PATHS:
		if player.has_node(path):
			_ok("has %s (%s)" % [path, player.get_node(path).get_class()])
		else:
			_fail("missing node %s" % path)
	player.free()

func _check_test_scene() -> void:
	print("Test scene")
	var packed: PackedScene = load("res://scenes/test/test_room.tscn")
	if packed == null:
		_fail("res://scenes/test/test_room.tscn did not load")
		return
	var room: Node = packed.instantiate()

	var interactables: Array[Node] = []
	_collect_interactables(room, interactables)
	if interactables.size() >= 3:
		_ok("%d Interactable objects found" % interactables.size())
	else:
		_fail("only %d Interactable objects found, expected 3+" % interactables.size())
	for node in interactables:
		_ok("  %s -> prompt \"%s\"" % [node.name, node.get_prompt()])

	if room.has_node("Player"):
		_ok("player instanced in the test scene")
	else:
		_fail("no Player node in the test scene")
	if room.has_node("InteractHUD"):
		_ok("HUD instanced in the test scene")
	else:
		_fail("no InteractHUD node in the test scene")

	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene == "res://scenes/ui/name_entry.tscn":
		_ok("main scene is the name-entry screen")
	else:
		_fail("main scene is \"%s\"" % main_scene)

	room.free()

func _collect_interactables(node: Node, out: Array[Node]) -> void:
	if node is Interactable:
		out.append(node)
	for child in node.get_children():
		_collect_interactables(child, out)
