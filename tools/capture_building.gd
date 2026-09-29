extends Node

## Dev utility: renders the gray-boxed building to PNGs so the layout can be reviewed without pressing Play.
## Run: godot --path <project> res://tools/capture_building.tscn -- <out_dir>

var _out_dir := "user://"
var _building: Node3D
var _player: PlayerController

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run()

func _run() -> void:
	GameState.set_player_name("Zahidul")
	_building = load("res://scenes/building/bic_building.tscn").instantiate()
	add_child(_building)
	for i in 10:
		await get_tree().process_frame
	_player = _building.get_node("Player")

	var print_door: Door = _building.get_node("Doors/DoorPrintRoom")
	var storage_door: Door = _building.get_node("Doors/DoorStorage")

	await _shot("10-desk-spawn.png")

	await _aim(Vector3(3.8, 0.02, 2.4), Vector3(6.1, 1.3, -1.6))
	await _shot("11-from-desk-to-entrance.png")

	await _aim(Vector3(3.6, 0.02, 1.0), Vector3(-2.6, 1.0, 0.1))
	await _shot("12-main-floor-rahat-desk.png")

	await _aim(Vector3(4.4, 0.02, -2.2), Vector3(4.4, 1.2, -3.6))
	await _shot("13-locked-storage-door.png")

	await _aim(Vector3(4.4, 0.02, 2.3), Vector3(4.4, 1.2, 3.2))
	_player._try_interact()
	await get_tree().create_timer(print_door.swing_time + 0.3).timeout
	await _shot("14-print-room-door-open.png")

	await _aim(Vector3(3.4, 0.02, 5.0), Vector3(-3.4, 1.0, 5.6))
	await _shot("15-print-room.png")

	storage_door.unlock()
	storage_door._set_open(true, true)
	var meeting_door: Door = _building.get_node("Doors/DoorMeetingRoom")
	meeting_door.unlock()
	meeting_door._set_open(true, true)
	await _aim(Vector3(4.4, 0.02, -5.0), Vector3(4.4, 1.2, -9.0))
	await _shot("16-spine-storage-to-meeting.png")

	await _aim(Vector3(3.2, 0.02, -4.6), Vector3(-4.0, 1.1, -6.4))
	await _shot("17-storage.png")

	await _aim(Vector3(3.0, 0.02, -8.8), Vector3(-1.6, 1.2, -11.6))
	await _shot("18-meeting-room-dead-end.png")

	get_tree().quit()

func _aim(from: Vector3, target: Vector3) -> void:
	_player.global_position = from
	_player.rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	var eye := from + Vector3(0, 1.6, 0)
	var flat := Vector2(target.x - eye.x, target.z - eye.z).length()
	_player.rotation.y = atan2(eye.x - target.x, eye.z - target.z)
	_player.head.rotation.x = atan2(target.y - eye.y, flat)
	# The InteractRay needs a few physics steps to re-resolve after a teleport.
	for i in 4:
		await get_tree().physics_frame

func _shot(file_name: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(file_name)
	var err := image.save_png(path)
	var hud: Node = _building.get_node("InteractHUD")
	print("%s %s   prompt=%s%s  activity=%s%s" % [
		"saved" if err == OK else "FAILED(%d)" % err, file_name,
		"\"" + hud.prompt_label.text + "\"", "" if hud.prompt_label.visible else " (hidden)",
		"\"" + hud.activity_label.text + "\"", "" if hud.activity_label.visible else " (hidden)"])
