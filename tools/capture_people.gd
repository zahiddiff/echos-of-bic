extends SceneTree

## Dev utility: renders a line-up of generated visitors next to their ID photos.
## Run: godot --path <project> --script res://tools/capture_people.gd -- <out.png>

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "user://people.png"
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1400, 800)

	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor.mesh = plane
	world.add_child(floor)

	var book := Rulebook.new()
	var photos: Array[Texture2D] = []
	for i in 5:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i * 17
		var request := RequestGenerator.new(book, rng).clean_request(TaskPool.by_id("schedule_lookup"))
		request.visitor_name = "Visitor %d" % i
		var figure := VisitorFigure.for_request(request)
		figure.position = Vector3((i - 2) * 0.75, 0, 0)
		figure.rotation.y = PI
		world.add_child(figure)
		photos.append(request.visitor_portrait)

	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.position = Vector3(0, 1.45, 3.6)
	cam.look_at(Vector3(0, 1.2, 0))

	var layer := CanvasLayer.new()
	root.add_child(layer)
	for i in photos.size():
		var rect := TextureRect.new()
		rect.texture = photos[i]
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.size = Vector2(96, 120)
		rect.position = Vector2(10 + i * 104, 10)
		layer.add_child(rect)

	for i in 12:
		await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png(out)
	# Close-up of the middle face.
	cam.position = Vector3(0, 1.62, 0.9)
	cam.look_at(Vector3(0, 1.6, 0))
	layer.visible = false
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(out.replace(".png", "-close.png"))
	quit()
