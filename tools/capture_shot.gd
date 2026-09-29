extends SceneTree

## Dev utility: renders the test room to PNGs so the foundation can be eyeballed without pressing Play.
## Run: godot --path <project> --script res://tools/capture_shot.gd -- <out_dir>

var _out_dir := "user://"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run.call_deferred()

func _run() -> void:
	var room: Node3D = load("res://scenes/test/test_room.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame

	var player: PlayerController = room.get_node("Player")
	var hud: InteractHUD = room.get_node("InteractHUD")
	var lamp: TestLamp = room.get_node("Room/Desk/DeskLamp")
	var cabinet: Interactable = room.get_node("Room/LockedCabinet")

	await _shot("01-spawn-view.png")

	await _aim(player, Vector3(-0.6, 0.02, -0.9), lamp.global_position + Vector3(0, 0.21, 0))
	await _shot("02-lamp-prompt.png")

	player._try_interact()
	await _shot("03-lamp-on.png")

	await _aim(player, Vector3(2.9, 0.02, -1.3), cabinet.global_position + Vector3(0, 0.5, 0))
	await _shot("04-locked-cabinet.png")

	print("HUD prompt at capture time: \"%s\" (visible=%s)" % [hud.prompt_label.text, hud.prompt_label.visible])
	quit()

func _aim(player: PlayerController, from: Vector3, target: Vector3) -> void:
	player.global_position = from
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	var eye := from + Vector3(0, 1.6, 0)
	var flat := Vector2(target.x - eye.x, target.z - eye.z).length()
	player.rotation.y = atan2(eye.x - target.x, eye.z - target.z)
	player.head.rotation.x = atan2(target.y - eye.y, flat)
	await physics_frame
	await physics_frame

func _shot(file_name: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 8:
		await process_frame
	var image := root.get_texture().get_image()
	var path := _out_dir.path_join(file_name)
	var err := image.save_png(path)
	print("%s -> %s" % ["saved" if err == OK else "FAILED(%d)" % err, path])
