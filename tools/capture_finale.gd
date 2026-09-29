extends Node

## Dev utility: screenshots of the lockdown, from the Dean's order to the ending.
## Run: godot --path <project> res://tools/capture_finale.tscn -- <out_dir>

var _out_dir := "user://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run()

func _run() -> void:
	GameState.reset()
	GameState.set_player_name("Zahidul")
	GameState.strikes_taken = GameState.MAX_STRIKES - 1
	var building: BICBuilding = load("res://scenes/building/bic_building.tscn").instantiate()
	building.shift = 7
	building.queue_seed = 9090
	building.pause_on_release = false
	building.decision_pause = 0.0
	add_child(building)
	await get_tree().create_timer(1.0).timeout
	building.runner._run_incident(building.runner.current())
	await get_tree().create_timer(4.0).timeout
	await _shot("40-lockdown-order.png")
	while building.finale_request == null:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.5).timeout
	await _shot("41-past-the-locked-doors.png")
	building.desk.sit(building.player)
	await get_tree().create_timer(1.5).timeout
	await _shot("42-flawless-papers.png")
	building._on_desk_action_clicked(building.records)
	await get_tree().create_timer(0.5).timeout
	building.terminal._on_submitted(building.finale_request.id_number)
	await get_tree().create_timer(1.0).timeout
	await _shot("43-terminal.png")
	get_tree().quit()

func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(file_name))
	print("saved ", file_name)
