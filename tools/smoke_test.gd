extends SceneTree

## Headless runtime smoke test for the Week 1-2 foundation.
## Run: godot --headless --path <project> --script res://tools/smoke_test.gd

var _failures := 0
var _room: Node3D
var _player: PlayerController
var _hud: InteractHUD

func _init() -> void:
	_run.call_deferred()

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

## Put the camera at `from`, pitched so it looks at `target`, then settle physics.
func _aim_at(from: Vector3, target: Vector3) -> void:
	_player.global_position = from
	_player.rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	var eye := from + Vector3(0, 1.6, 0)
	var flat := Vector2(target.x - eye.x, target.z - eye.z).length()
	_player.rotation.y = atan2(eye.x - target.x, eye.z - target.z)
	_player.head.rotation.x = atan2(target.y - eye.y, flat)
	await physics_frame
	await physics_frame

func _run() -> void:
	print("Smoke test")
	_room = load("res://scenes/test/test_room.tscn").instantiate()
	root.add_child(_room)
	await physics_frame

	_player = _room.get_node("Player")
	_hud = _room.get_node("InteractHUD")
	var lamp: TestLamp = _room.get_node("Room/Desk/DeskLamp")
	var stamp: StampAction = _room.get_node("Room/Desk/ApprovalStamp")
	var cabinet: Interactable = _room.get_node("Room/LockedCabinet")

	# --- Looking at nothing ------------------------------------------------
	await _aim_at(Vector3(0, 0.02, 1.0), Vector3(0, 1.6, 2.9))
	_expect(_player._current_focus == null, "empty wall -> no focus")
	_expect(not _hud.prompt_label.visible, "empty wall -> prompt hidden")

	# --- Desk lamp: toggle on, then off ------------------------------------
	await _aim_at(Vector3(-0.6, 0.02, -0.9), lamp.global_position + Vector3(0, 0.21, 0))
	_expect(_player._current_focus == lamp, "looking at lamp -> focus is DeskLamp")
	_expect(_hud.prompt_label.visible, "looking at lamp -> prompt visible")
	_expect(_hud.prompt_label.text == "Turn on the lamp",
		"lamp prompt reads \"Turn on the lamp\" (got \"%s\")" % _hud.prompt_label.text)

	var light: OmniLight3D = lamp.get_node("OmniLight3D")
	_expect(not light.visible, "lamp light starts off")
	_player._try_interact()
	_expect(lamp.is_on, "E on lamp -> is_on true")
	_expect(light.visible, "E on lamp -> OmniLight3D visible")
	_expect(_hud.prompt_label.text == "Turn off the lamp",
		"prompt flipped to \"Turn off the lamp\" (got \"%s\")" % _hud.prompt_label.text)
	_player._try_interact()
	_expect(not lamp.is_on, "E again -> lamp back off")

	# --- Locked cabinet ----------------------------------------------------
	await _aim_at(Vector3(2.9, 0.02, -1.3), cabinet.global_position + Vector3(0, 0.5, 0))
	_expect(_player._current_focus == cabinet, "looking at cabinet -> focus is LockedCabinet")
	_expect(_hud.prompt_label.text == "Locked — no key",
		"locked prompt shown (got \"%s\")" % _hud.prompt_label.text)
	var used_fired := [false]
	cabinet.used.connect(func(_p: Node) -> void: used_fired[0] = true)
	_player._try_interact()
	_expect(not used_fired[0], "E on locked cabinet -> `used` does NOT fire")

	# --- Approval stamp (examples/stamp_action.gd) -------------------------
	await _aim_at(Vector3(0.5, 0.02, -0.9), stamp.global_position + Vector3(0, 0.09, 0))
	_expect(_player._current_focus == stamp, "looking at stamp -> focus is ApprovalStamp")
	_expect(_hud.prompt_label.text == "Stamp APPROVED",
		"stamp prompt shown (got \"%s\")" % _hud.prompt_label.text)
	var approved := [""]
	stamp.document_approved.connect(func(doc: Node) -> void: approved[0] = doc.name)
	_expect(stamp.current_document != null, "stamp has a placeholder document loaded")
	_player._try_interact()
	_expect(approved[0] == "PlaceholderForm",
		"E on stamp -> document_approved fired (got \"%s\")" % approved[0])

	if _failures == 0:
		print("\nSMOKE TEST PASSED")
	else:
		print("\nSMOKE TEST FAILED (%d problem(s))" % _failures)
	quit(1 if _failures > 0 else 0)
