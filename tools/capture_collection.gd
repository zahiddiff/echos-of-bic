extends Node

## Dev utility: screenshots of a physical task, from the waiting form to the printout on the desk.
## Run: godot --path <project> res://tools/capture_collection.tscn -- <out_dir>

const L := preload("res://code/world/building_layout.gd")

var _out_dir := "user://"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run()

func _run() -> void:
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var building: BICBuilding = load("res://scenes/building/bic_building.tscn").instantiate()
	building.shift = 2
	building.queue_seed = 4040
	building.pause_on_release = false
	building.decision_pause = 0.0
	add_child(building)
	await get_tree().process_frame
	var request := building.current_request()
	request.task_id = "transcript_print"
	request.task_label = "Transcript printing"
	request.is_threat = true
	request.threat_kind = ThreatType.Kind.THIEF
	request.item_name = NameBank.near_miss(request.form_name, RandomNumberGenerator.new())
	building._refresh_collection()
	await get_tree().create_timer(9.0).timeout

	building.desk.sit(building.player)
	await get_tree().create_timer(1.0).timeout
	await _shot("30-desk-waiting.png")
	building.desk.stand()
	await get_tree().create_timer(1.2).timeout

	var player := building.player
	await _aim(player, Vector3(-1.6, 0.02, 4.4), Vector3(-3.0, 0.9, 5.1))
	await get_tree().create_timer(0.4).timeout
	await _shot("31-printer.png")

	await get_tree().create_timer(5.0).timeout
	await _aim(player, Vector3(3.9, 0.02, 2.3), Vector3(1.0, 1.2, 1.5))
	await _shot("32-staff-side.png")

	(building.collection_points[0] as CollectionPoint).interact(player)
	await get_tree().create_timer(6.0).timeout
	building.desk.sit(building.player)
	await get_tree().create_timer(1.0).timeout
	await _shot("33-desk-printout.png")
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
