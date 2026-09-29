extends Node

## Dev utility: renders the desk view, the shift report and the ending screen to PNGs.
## Run: godot --path <project> res://tools/capture_ui.tscn -- <out_dir>

var _out_dir := "user://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run()

func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var building: BICBuilding = load("res://scenes/building/bic_building.tscn").instantiate()
	building.queue_seed = 4242
	building.decision_pause = 0.0
	building.pause_on_release = false
	add_child(building)
	for i in 10:
		await get_tree().process_frame
	var player := building.player

	# People coming in through the front doors, then the first one at the counter.
	await get_tree().create_timer(3.2).timeout
	await _aim(player, Vector3(3.8, 0.02, 2.4), Vector3(6.1, 1.3, -1.6))
	await _shot("18-arrivals.png")
	await get_tree().create_timer(6.0).timeout
	await _aim(player, Vector3(3.0, 0.02, 2.1), Vector3(3.05, 1.45, 0.05))
	await _shot("19-counter.png")

	# Sit down with the first visitor at the counter.
	building.desk.sit(building.player)
	await get_tree().create_timer(1.5).timeout
	await _shot("20-desk.png")
	building.viewer.stamp_mark(true)
	await get_tree().create_timer(0.4).timeout
	await _shot("21-desk-approved.png")

	building.desk.stand()
	building.pause_menu.open("Shift 1  ·  21:04")
	await _shot("22-pause.png")
	building.pause_menu.close()

	building.tally = {"approved": 6, "rejected": 2, "flagged": 1}
	building.status_bar.visible = false
	building.report.show_report({
		"shift": 1, "training": true, "reason": ShiftRunner.EndReason.QUEUE_FINISHED,
		"seen": 9, "total": 9, "approved": 6, "rejected": 2, "flagged": 1,
		"strikes_left": 5, "clock_out": "23:12", "run_over": false,
	})
	await get_tree().create_timer(2.2).timeout
	await _shot("23-shift-report.png")

	building.report.show_ending(GameState.Ending.STANDARD, Dean.ending_lines(GameState.Ending.STANDARD))
	await get_tree().create_timer(6.5).timeout
	await _shot("24-ending.png")
	get_tree().quit()

func _aim(player: PlayerController, from: Vector3, target: Vector3) -> void:
	player.global_position = from
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	var eye := from + Vector3(0, 1.6, 0)
	var flat := Vector2(target.x - eye.x, target.z - eye.z).length()
	player.rotation.y = atan2(eye.x - target.x, eye.z - target.z)
	player.head.rotation.x = atan2(target.y - eye.y, flat)
	for i in 4:
		await get_tree().physics_frame

func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(file_name))
	print("saved ", file_name)
