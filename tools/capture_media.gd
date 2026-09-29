extends Node

## Dev utility: renders store capsules and key art at their exact sizes, offscreen.
## Run: godot --path <project> res://tools/capture_media.tscn -- <out_dir>

const L := preload("res://code/world/building_layout.gd")

## name, size, where the title goes ("left", "top", "none", or "space_left": framed for a title added elsewhere).
const CAPSULES := [
	["header_capsule", Vector2i(920, 430), "left"],
	["main_capsule", Vector2i(1232, 706), "left"],
	["small_capsule", Vector2i(462, 174), "left"],
	["vertical_capsule", Vector2i(748, 896), "top"],
	["library_capsule", Vector2i(600, 900), "top"],
	["library_hero", Vector2i(3840, 1240), "none"],
	["itch_cover", Vector2i(630, 500), "left"],
	["key_art", Vector2i(1920, 1080), "left"],
	["social_card", Vector2i(1200, 630), "left"],
	["key_art_clean", Vector2i(1920, 1080), "space_left"],
]

var _out_dir := "user://media"
var building: BICBuilding

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run()

func _run() -> void:
	GameState.reset()
	GameState.set_player_name("Zahidul")
	GameState.shift = 2
	building = load("res://scenes/building/bic_building.tscn").instantiate()
	building.shift = 2
	building.queue_seed = 2718
	building.pause_on_release = false
	add_child(building)
	await get_tree().process_frame
	for layer in [building.hud, building.status_bar, building.dialogue]:
		layer.visible = false

	# Wait for the first visitor to reach the counter and the next to join the queue.
	await get_tree().create_timer(11.0).timeout
	var figure := building.stage.at_counter
	if figure:
		figure.face(Vector3(L.SEAT.x, 0, L.SEAT.z) + Vector3(-0.5, 0, 0), true)

	for spec in CAPSULES:
		await _render(spec[0], spec[1], spec[2])
	get_tree().quit()

func _render(file_name: String, size: Vector2i, layout: String) -> void:
	var view := SubViewport.new()
	view.size = size
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var aspect := float(size.x) / float(size.y)
	var cam := Camera3D.new()
	cam.fov = 42.0 if aspect >= 1.0 else 58.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT if aspect >= 1.0 else Camera3D.KEEP_WIDTH
	view.add_child(cam)
	var face := Vector3(L.VISITOR_SPOT.x, 1.55, L.VISITOR_SPOT.z)
	# The visitor sits in the right third when the title is on the left, centred otherwise.
	var sideways := clampf((aspect - 1.0) * 0.55, 0.0, 1.1) if layout in ["left", "space_left"] else 0.0
	cam.position = Vector3(face.x - 0.1 - sideways * 0.5, 1.48, face.z + 2.0)
	var look := face + Vector3(-sideways * 1.45, -0.18 if aspect < 1.0 else -0.08, 0)
	if layout == "top":
		look.y += 0.28
	cam.look_at_from_position(cam.position, look)
	cam.current = true

	_grade(view, size)
	if layout == "left" or layout == "top":
		_overlay(view, size, layout)

	for i in 6:
		await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.save_png(_out_dir.path_join("%s.png" % file_name))
	print("saved %s (%dx%d)" % [file_name, size.x, size.y])
	view.queue_free()
	await get_tree().process_frame

## Late-shift grade: cooler, darker, and falling off to black at the edges.
func _grade(view: SubViewport, size: Vector2i) -> void:
	var tint := ColorRect.new()
	tint.color = Color(0.62, 0.68, 0.8)
	tint.size = Vector2(size)
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint.material = multiply
	view.add_child(tint)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0.0, 0.0, 0.01, 0.85))
	gradient.set_offset(0, 0.35)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.62, 0.42)
	texture.fill_to = Vector2(1.25, 1.1)
	texture.width = 256
	texture.height = 256
	var vignette := TextureRect.new()
	vignette.texture = texture
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.size = Vector2(size)
	view.add_child(vignette)

## Darken one side and set the title into it.
func _overlay(view: SubViewport, size: Vector2i, layout: String) -> void:
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.03, 0.94))
	gradient.set_color(1, Color(0.02, 0.02, 0.03, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	if layout == "left":
		texture.fill_from = Vector2(0.0, 0.5)
		texture.fill_to = Vector2(0.72, 0.5)
	else:
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 0.42)
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(size)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.add_child(shade)

	var short := float(mini(size.x, size.y))
	var title_size := int(short * (0.095 if layout == "left" else 0.085))
	if size.y < 200:
		title_size = int(size.y * 0.2)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(title_size * 0.2))
	var title := Label.new()
	title.text = "ECHOES OF BIC"
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", UiKit.ACCENT)
	box.add_child(title)
	if size.y >= 200:
		var line := Label.new()
		line.text = "A realistic horror job simulator"
		line.add_theme_font_size_override("font_size", maxi(int(title_size * 0.36), 12))
		line.add_theme_color_override("font_color", UiKit.INK)
		box.add_child(line)
	view.add_child(box)
	var margin := short * 0.07
	if layout == "left":
		box.position = Vector2(margin * 1.2, size.y * 0.5 - title_size * 0.9)
		if size.y < 200:
			box.position = Vector2(margin, size.y * 0.5 - title_size * 0.65)
	else:
		box.position = Vector2(margin, margin)
