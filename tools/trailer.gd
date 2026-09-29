extends Node

## Scripted trailer, recorded with Movie Maker.
## Run: godot --path <project> --write-movie trailer.avi --fixed-fps 30 --resolution 1920x1080 res://tools/trailer.tscn

const L := preload("res://code/world/building_layout.gd")

var building: BICBuilding
var cam: Camera3D
var _card_layer: CanvasLayer
var _shade: ColorRect
var _title: Label
var _line: Label

func _ready() -> void:
	_run()

func _run() -> void:
	GameState.reset()
	GameState.set_player_name("Zahidul")
	GameState.shift = 2
	building = load("res://scenes/building/bic_building.tscn").instantiate()
	building.shift = 2
	building.queue_seed = 2718
	building.pause_on_release = false
	building.decision_pause = 0.0
	add_child(building)
	_build_cards()
	await get_tree().process_frame
	building.hud.visible = false
	building.status_bar.visible = false
	cam = Camera3D.new()
	cam.fov = 55
	building.add_child(cam)
	cam.make_current()
	_frame(Vector3(4.6, 1.55, 2.6), Vector3(6.2, 1.2, -1.4))

	# 1. The job.
	_shade.modulate.a = 1.0
	await _card("", "Your first job.", 3.0)

	# 2. Someone comes in through the front doors.
	await _fade_shade(0.0, 0.8)
	_dolly(Vector3(4.6, 1.55, 2.6), Vector3(4.2, 1.5, 2.2), Vector3(6.2, 1.2, -1.4), Vector3(3.2, 1.4, -0.2), 6.5)
	await _wait(6.5)

	# 3. The counter.
	_frame(Vector3(3.0, 1.55, 1.75), Vector3(3.05, 1.5, 0.05))
	_dolly(Vector3(3.0, 1.55, 1.9), Vector3(3.0, 1.58, 1.35), Vector3(3.05, 1.5, 0.05), Vector3(3.05, 1.55, 0.05), 3.5)
	await _wait(3.5)

	await _card("", "Check their papers.", 2.4)

	# 4. The desk: papers, the magnifier over the photo, then the face.
	building.desk.sit(building.player)
	await _wait(0.6)
	building.player.camera.make_current()
	building.dialogue.visible = false
	await _fade_shade(0.0, 0.5)
	var viewer := building.viewer
	var mag := viewer.magnifier
	var id_centre := viewer.id_photo.global_position + viewer.id_photo.size * 0.5
	var face_centre := viewer.visitor_photo.global_position + viewer.visitor_photo.size * 0.5
	mag.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_method(func(p: Vector2) -> void:
		mag.global_position = p - mag.size * 0.5
		mag._refresh(), mag.lens_centre(), id_centre + Vector2(0, -20), 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_interval(1.2)
	t.tween_method(func(p: Vector2) -> void:
		mag.global_position = p - mag.size * 0.5
		mag._refresh(), id_centre + Vector2(0, -20), face_centre + Vector2(0, -30), 1.6).set_trans(Tween.TRANS_SINE)
	await _wait(5.8)
	viewer.stamp_mark(true)
	_play(building.audio.stamp)
	await _wait(1.6)

	await _card("", "Most people are exactly who they say they are.", 3.2)

	# 5. A face, close, and the eyes going to the door before the answer.
	building.desk.stand()
	building.viewer.visible = false
	building.hud.visible = false
	cam.make_current()
	var figure := building.stage.at_counter
	await _wait(0.4)
	figure = building.stage.at_counter
	if figure:
		var face := figure.head.global_position + Vector3(0, 0.12, 0)
		var toward := (Vector3(L.SEAT.x, 0, L.SEAT.z) - Vector3(face.x, 0, face.z)).normalized()
		var look := face + Vector3(0, -0.12, 0)
		_frame(face + toward * 1.7 + Vector3(0.3, 0.0, 0), look)
		_dolly(face + toward * 1.7 + Vector3(0.3, 0.0, 0), face + toward * 1.3 + Vector3(0.2, 0.0, 0), look, look, 6.0)
		await _fade_shade(0.0, 0.5)
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			figure.perform(DialogueLine.Delivery.CHECKS_EXIT, 0.0, 2.6, building.stage.exit_point()))
		building.dialogue.visible = true
		building.dialogue.play_sequence("You", PackedStringArray(["Is this for you?"]))
		building.dialogue.play_sequence(building.stage.at_counter_request.visitor_name,
			PackedStringArray([DialogueAuthor.TELL_ANSWERS[DialogueLine.Delivery.CHECKS_EXIT]]))
		await _wait(5.5)
	building.dialogue.visible = false

	await _card("", "Some are not.", 2.6)

	# 6. Nothing happens. Then the Dean comes down.
	_frame(Vector3(3.3, 1.6, 2.3), Vector3(5.8, 1.4, -1.6))
	await _fade_shade(0.0, 0.6)
	building.stage.dean_arrives()
	_dolly(Vector3(3.3, 1.6, 2.3), Vector3(3.2, 1.6, 2.0), Vector3(5.8, 1.4, -1.6), Vector3(3.1, 1.55, 0.1), 7.0)
	await _wait(5.2)
	building.dialogue.visible = true
	var lines := Dean.arrival_lines(1, GameState.player_name)
	building.dialogue.play_sequence(Dean.NAME, PackedStringArray([lines[0], lines[1]]))
	await _wait(7.5)

	await _card("", "Nothing tells you when you get one wrong.", 3.0)

	# 7. Title.
	_shade.modulate.a = 1.0
	_title.text = "ECHOES OF BIC"
	_line.text = "A realistic horror job simulator"
	_title.modulate.a = 0.0
	_line.modulate.a = 0.0
	var tt := create_tween()
	tt.tween_property(_title, "modulate:a", 1.0, 1.2)
	tt.tween_property(_line, "modulate:a", 1.0, 0.8)
	await _wait(3.4)
	var t2 := create_tween()
	t2.tween_property(_line, "modulate:a", 0.0, 0.4)
	t2.tween_callback(func() -> void: _line.text = "Play the demo free in your browser")
	t2.tween_property(_line, "modulate:a", 1.0, 0.6)
	await _wait(3.2)
	get_tree().quit()

# --- Helpers -------------------------------------------------------------------------

func _build_cards() -> void:
	_card_layer = CanvasLayer.new()
	_card_layer.layer = 100
	add_child(_card_layer)
	_shade = UiKit.fill(ColorRect.new()) as ColorRect
	_shade.color = Color(0.015, 0.015, 0.02)
	_card_layer.add_child(_shade)
	var centre := UiKit.fill(VBoxContainer.new()) as VBoxContainer
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 14)
	_card_layer.add_child(centre)
	_title = UiKit.label("", 64, UiKit.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_title)
	_line = UiKit.label("", 26, UiKit.INK)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_line)

## Black card with one line on it, then fade back out to whatever the camera sees.
func _card(title: String, line: String, seconds: float) -> void:
	_title.text = title
	_line.text = line
	_line.modulate.a = 0.0
	await _fade_shade(1.0, 0.5)
	var t := create_tween()
	t.tween_property(_line, "modulate:a", 1.0, 0.5)
	t.tween_interval(maxf(seconds - 1.0, 0.2))
	t.tween_property(_line, "modulate:a", 0.0, 0.5)
	await t.finished

func _fade_shade(alpha: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(_shade, "modulate:a", alpha, seconds)
	await t.finished

func _frame(from: Vector3, target: Vector3) -> void:
	cam.global_position = from
	cam.look_at(target)

func _dolly(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, seconds: float) -> void:
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		cam.global_position = from.lerp(to, k)
		cam.look_at(look_from.lerp(look_to, k)), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
