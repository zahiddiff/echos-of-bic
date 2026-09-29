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
	add_child(building)
	for i in 10:
		await get_tree().process_frame
	building.pause_menu.set_process(false)

	# Sit down with the first visitor at the counter.
	await get_tree().create_timer(9.0).timeout
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

func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(file_name))
	print("saved ", file_name)
