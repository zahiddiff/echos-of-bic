@tool
extends AnimatableBody3D
class_name VisitorFigure

## A person in the building.

enum Pose { STANDING, SEATED }

signal arrived()
signal departed()

@export var skin: Color = Color(0.78, 0.62, 0.50):
	set(value):
		skin = value
		_recolour()
@export var hair: Color = Color(0.12, 0.10, 0.09):
	set(value):
		hair = value
		_recolour()
@export var jacket: Color = Color(0.26, 0.29, 0.34):
	set(value):
		jacket = value
		_recolour()
@export var trousers: Color = Color(0.17, 0.18, 0.21):
	set(value):
		trousers = value
		_recolour()
@export var shirt: Color = Color(0.86, 0.86, 0.84):
	set(value):
		shirt = value
		_recolour()
@export var eyes: Color = Color(0.24, 0.15, 0.09):
	set(value):
		eyes = value
		_recolour()
@export var pose: Pose = Pose.STANDING:
	set(value):
		pose = value
		if _built:
			_apply_pose()

@export_group("Look")
@export var hair_style: PortraitFactory.Hair = PortraitFactory.Hair.SHORT:
	set(value):
		hair_style = value
		_rebuild()
@export var facial_hair: PortraitFactory.FacialHair = PortraitFactory.FacialHair.NONE:
	set(value):
		facial_hair = value
		_rebuild()
@export var glasses: bool = false:
	set(value):
		glasses = value
		_rebuild()
## Overall size; 1 is about 1.75 m.
@export_range(0.85, 1.15) var stature: float = 1.0:
	set(value):
		stature = value
		if _rig:
			_rig.scale = Vector3.ONE * stature
@export_group("")

## Walking pace in metres per second.
@export var walk_speed: float = 1.1

## Joint pivots — public so a test, or a future rig adapter, can read the pose.
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var forearm_l: Node3D
var forearm_r: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var shin_l: Node3D
var shin_r: Node3D

var is_walking: bool = false
## Whatever the figure is doing with its body right now, for tests and debug.
var current_tell: int = -1

const HIP_Y := 0.90
const SEATED_HIP_Y := 0.47
const ELBOW_REST := -0.18

var _built := false
var _rig: Node3D
var _eyes: Array[Node3D] = []
var _materials: Dictionary = {}
var _path: PackedVector3Array = PackedVector3Array()
var _target_yaw := 0.0
var _walk_phase := 0.0
var _idle_t := 0.0
var _next_blink := 2.0
var _tell_tween: Tween
var _busy_until := 0.0
var _then: Callable

func _ready() -> void:
	# Moved by setting its transform directly.
	sync_to_physics = false
	_build()
	_target_yaw = rotation.y
	_next_blink = randf_range(1.5, 4.0)
	collision_layer = 2
	collision_mask = 0

# --- Construction ---------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	for key in ["skin", "hair", "jacket", "trousers", "dark", "shirt", "lip", "white", "iris", "frame"]:
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.85
		_materials[key] = mat
	(_materials["skin"] as StandardMaterial3D).roughness = 0.62
	(_materials["white"] as StandardMaterial3D).roughness = 0.3
	(_materials["iris"] as StandardMaterial3D).roughness = 0.25
	(_materials["hair"] as StandardMaterial3D).roughness = 0.7
	_recolour()

	_rig = _pivot(self, "Rig", Vector3.ZERO)
	_rig.scale = Vector3.ONE * stature

	# Legs: thigh pivots at the hip, shin pivots at the knee.
	thigh_l = _pivot(_rig, "ThighL", Vector3(-0.085, HIP_Y, 0))
	thigh_r = _pivot(_rig, "ThighR", Vector3(0.085, HIP_Y, 0))
	for thigh in [thigh_l, thigh_r]:
		_part(thigh, _tapered(0.07, 0.058, 0.46), Vector3(0, -0.23, 0), "trousers")
	shin_l = _pivot(thigh_l, "ShinL", Vector3(0, -0.45, 0))
	shin_r = _pivot(thigh_r, "ShinR", Vector3(0, -0.45, 0))
	for shin in [shin_l, shin_r]:
		_part(shin, _tapered(0.06, 0.05, 0.42), Vector3(0, -0.21, 0), "trousers")
		var shoe := _part(shin, _capsule(0.052, 0.26), Vector3(0, -0.425, -0.045), "dark")
		shoe.rotation.x = deg_to_rad(90.0)
		shoe.scale = Vector3(1.0, 1.0, 0.62)

	# Torso pivots at the hip, so leaning and breathing move everything above.
	torso = _pivot(_rig, "Torso", Vector3(0, HIP_Y, 0))
	var hips := _part(torso, _tapered(0.16, 0.15, 0.2), Vector3(0, 0.04, 0), "trousers")
	hips.scale = Vector3(1.0, 1.0, 0.68)
	var belly := _part(torso, _tapered(0.15, 0.175, 0.30), Vector3(0, 0.22, 0), "jacket")
	belly.scale = Vector3(1.0, 1.0, 0.68)
	var chest := _part(torso, _tapered(0.2, 0.175, 0.24), Vector3(0, 0.40, 0), "jacket")
	chest.scale = Vector3(1.05, 1.0, 0.62)
	var yoke := _part(torso, _capsule(0.06, 0.42), Vector3(0, 0.50, 0), "jacket")
	yoke.rotation.z = deg_to_rad(90.0)
	yoke.scale = Vector3(1.0, 1.0, 0.95)
	# Shirt showing in the open collar.
	var collar := _part(torso, _prism(Vector3(0.10, 0.11, 0.012)), Vector3(0, 0.49, -0.112), "shirt")
	collar.rotation.z = PI

	arm_l = _pivot(torso, "ArmL", Vector3(-0.225, 0.50, 0))
	arm_r = _pivot(torso, "ArmR", Vector3(0.225, 0.50, 0))
	forearm_l = _pivot(arm_l, "ForearmL", Vector3(0, -0.29, 0))
	forearm_r = _pivot(arm_r, "ForearmR", Vector3(0, -0.29, 0))
	for arm in [arm_l, arm_r]:
		_part(arm, _sphere(0.058), Vector3(0, -0.015, 0), "jacket")
		_part(arm, _tapered(0.056, 0.047, 0.30), Vector3(0, -0.145, 0), "jacket")
	for forearm in [forearm_l, forearm_r]:
		forearm.rotation.x = ELBOW_REST
		_part(forearm, _tapered(0.046, 0.038, 0.26), Vector3(0, -0.13, 0), "jacket")
		_part(forearm, _cylinder(0.034, 0.03), Vector3(0, -0.27, 0), "skin")
		var hand := _part(forearm, _sphere(0.045), Vector3(0, -0.32, -0.005), "skin")
		hand.scale = Vector3(0.62, 1.25, 1.0)
		var thumb := _part(forearm, _capsule(0.013, 0.06), Vector3(0, -0.305, -0.03), "skin")
		thumb.rotation.x = deg_to_rad(30.0)

	_part(torso, _tapered(0.045, 0.05, 0.1), Vector3(0, 0.565, -0.005), "skin")

	# The head pivots at the top of the neck and faces -Z.
	head = _pivot(torso, "Head", Vector3(0, 0.575, 0))
	_build_head()

	var collider := CollisionShape3D.new()
	collider.name = "Body"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.7
	collider.shape = shape
	collider.position = Vector3(0, 0.85, 0)
	add_child(collider)

	_apply_pose()

func _build_head() -> void:
	var skull := _part(head, _sphere(0.098), Vector3(0, 0.125, 0.008), "skin")
	skull.scale = Vector3(0.9, 1.1, 1.0)
	var jaw := _part(head, _sphere(0.078), Vector3(0, 0.07, -0.022), "skin")
	jaw.scale = Vector3(0.95, 0.9, 1.0)
	var chin := _part(head, _sphere(0.028), Vector3(0, 0.038, -0.06), "skin")
	chin.scale = Vector3(1.2, 0.9, 0.9)

	var nose := _part(head, _prism(Vector3(0.022, 0.04, 0.022)), Vector3(0, 0.108, -0.095), "skin")
	nose.rotation.x = deg_to_rad(-12.0)
	_part(head, _sphere(0.0105), Vector3(0, 0.091, -0.1), "skin")
	for side in [-1.0, 1.0]:
		var ear := _part(head, _sphere(0.026), Vector3(0.087 * side, 0.115, 0.01), "skin")
		ear.scale = Vector3(0.45, 1.0, 0.75)
		# Brow ridge, then the eye tucked under it.
		var brow := _part(head, _box(Vector3(0.036, 0.007, 0.012)), Vector3(0.033 * side, 0.152, -0.091), "hair")
		brow.rotation.z = deg_to_rad(-6.0 * side)
		var eye := _pivot(head, "Eye", Vector3(0.032 * side, 0.132, -0.08))
		var white := _part(eye, _sphere(0.012), Vector3.ZERO, "white")
		white.scale = Vector3(1.2, 0.7, 0.6)
		_part(eye, _sphere(0.006), Vector3(0, 0, -0.0055), "iris")
		_eyes.append(eye)

	var lip_top := _part(head, _capsule(0.005, 0.036), Vector3(0, 0.064, -0.088), "lip")
	lip_top.rotation.z = deg_to_rad(90.0)
	var lip_low := _part(head, _capsule(0.006, 0.032), Vector3(0, 0.056, -0.086), "lip")
	lip_low.rotation.z = deg_to_rad(90.0)

	_build_hair()

	if facial_hair == PortraitFactory.FacialHair.BEARD:
		var beard := _part(head, _sphere(0.08), Vector3(0, 0.058, -0.03), "hair")
		beard.scale = Vector3(0.98, 0.78, 1.0)
	if facial_hair in [PortraitFactory.FacialHair.BEARD, PortraitFactory.FacialHair.MOUSTACHE]:
		var tache := _part(head, _capsule(0.008, 0.05), Vector3(0, 0.074, -0.097), "hair")
		tache.rotation.z = deg_to_rad(90.0)

	if glasses:
		for side in [-1.0, 1.0]:
			var rim := _part(head, _torus(0.019, 0.023), Vector3(0.033 * side, 0.132, -0.1), "frame")
			rim.rotation.x = deg_to_rad(90.0)
			rim.scale = Vector3(1.2, 1.0, 0.85)
			_part(head, _box(Vector3(0.004, 0.004, 0.1)), Vector3(0.084 * side, 0.135, -0.05), "frame")
		_part(head, _box(Vector3(0.022, 0.004, 0.004)), Vector3(0, 0.136, -0.104), "frame")

func _build_hair() -> void:
	var H := PortraitFactory.Hair
	var cap_scale := Vector3(0.95, 0.9, 1.04)
	var cap_at := Vector3(0, 0.155, 0.018)
	var radius := 0.1
	if hair_style == H.BUZZ:
		radius = 0.097
		cap_at = Vector3(0, 0.145, 0.012)
	var cap := _part(head, _sphere(radius), cap_at, "hair")
	cap.scale = cap_scale
	# The back of the head down to the nape.
	var nape := _part(head, _sphere(0.085), Vector3(0, 0.1, 0.04), "hair")
	nape.scale = Vector3(1.0, 0.9, 0.8)

	match hair_style:
		H.LONG:
			var fall := _part(head, _capsule(0.09, 0.3), Vector3(0, 0.02, 0.05), "hair")
			fall.scale = Vector3(1.12, 1.0, 0.55)
			for side in [-1.0, 1.0]:
				var lock := _part(head, _capsule(0.03, 0.2), Vector3(0.078 * side, 0.06, -0.02), "hair")
				lock.scale = Vector3(1.0, 1.0, 1.3)
		H.BUN:
			_part(head, _sphere(0.045), Vector3(0, 0.235, 0.06), "hair")
		H.SIDE_PART:
			var sweep := _part(head, _sphere(0.06), Vector3(-0.035, 0.215, -0.045), "hair")
			sweep.scale = Vector3(1.4, 0.6, 1.0)

func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		if child != null and child.name in ["Rig", "Body"]:
			remove_child(child)
			child.free()
	_eyes.clear()
	_built = false
	_build()

func _pivot(parent: Node, node_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node

func _part(parent: Node, mesh: Mesh, at: Vector3, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _prism(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh

func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 6
	return mesh

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 16
	mesh.rings = 6
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	return _tapered(radius, radius, height)

## A limb segment, wider at the top.
func _tapered(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	return mesh

func _recolour() -> void:
	if _materials.is_empty():
		return
	(_materials["skin"] as StandardMaterial3D).albedo_color = skin
	(_materials["hair"] as StandardMaterial3D).albedo_color = hair
	(_materials["jacket"] as StandardMaterial3D).albedo_color = jacket
	(_materials["trousers"] as StandardMaterial3D).albedo_color = trousers
	(_materials["shirt"] as StandardMaterial3D).albedo_color = shirt
	(_materials["dark"] as StandardMaterial3D).albedo_color = Color(0.07, 0.07, 0.08)
	(_materials["lip"] as StandardMaterial3D).albedo_color = skin.lerp(Color(0.62, 0.30, 0.32), 0.4)
	(_materials["white"] as StandardMaterial3D).albedo_color = Color(0.86, 0.85, 0.82)
	(_materials["iris"] as StandardMaterial3D).albedo_color = eyes.darkened(0.3)
	(_materials["frame"] as StandardMaterial3D).albedo_color = Color(0.08, 0.08, 0.09)

func _apply_pose() -> void:
	if pose == Pose.SEATED:
		torso.position.y = SEATED_HIP_Y
		for thigh in [thigh_l, thigh_r]:
			thigh.position.y = SEATED_HIP_Y
			thigh.rotation.x = deg_to_rad(90.0)
		for shin in [shin_l, shin_r]:
			shin.rotation.x = deg_to_rad(-90.0)
		# Forearms forward, resting toward the desk.
		for forearm in [forearm_l, forearm_r]:
			forearm.rotation.x = deg_to_rad(-70.0)
	else:
		torso.position.y = HIP_Y
		for thigh in [thigh_l, thigh_r]:
			thigh.position.y = HIP_Y
			thigh.rotation.x = 0.0
		for shin in [shin_l, shin_r]:
			shin.rotation.x = 0.0
		for forearm in [forearm_l, forearm_r]:
			forearm.rotation.x = ELBOW_REST

# --- Appearance from paperwork -------------------------------------------------

## Build a figure for a visitor, matching the face on their ID so the person across the counter is recognisably the person in the photo.
static func for_request(request: VisitorRequest) -> VisitorFigure:
	var figure := VisitorFigure.new()
	figure.name = "Visitor"
	var face := request.visitor_face
	if face:
		figure.skin = face.skin
		figure.hair = face.hair
		figure.eyes = face.eyes
		figure.jacket = face.clothes
		figure.shirt = face.inner
		figure.hair_style = face.hair_style
		figure.facial_hair = face.facial_hair
		figure.glasses = face.glasses
		figure.stature = face.height
	else:
		var colours := colours_from_portrait(request.visitor_portrait)
		figure.skin = colours.get("skin", figure.skin)
		figure.hair = colours.get("hair", figure.hair)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(request.visitor_name)
	var jackets := [Color(0.24, 0.27, 0.32), Color(0.33, 0.30, 0.26), Color(0.20, 0.24, 0.22),
		Color(0.38, 0.36, 0.34), Color(0.28, 0.20, 0.20), Color(0.16, 0.17, 0.20),
		Color(0.45, 0.43, 0.40)]
	var legs := [Color(0.16, 0.17, 0.20), Color(0.22, 0.24, 0.30), Color(0.30, 0.28, 0.25)]
	if face == null:
		figure.jacket = jackets[rng.randi() % jackets.size()]
	figure.trousers = legs[rng.randi() % legs.size()]
	return figure

## Sample skin and hair from a portrait: a cheek below the eyes, and the hair above the forehead.
static func colours_from_portrait(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {}
	var w := image.get_width()
	var h := image.get_height()
	return {
		"skin": _average(image, int(w * 0.40), int(h * 0.50)),
		"hair": _average(image, int(w * 0.5), int(h * 0.13)),
	}

static func _average(image: Image, cx: int, cy: int) -> Color:
	var total := Color(0, 0, 0, 0)
	var count := 0
	for y in range(cy - 2, cy + 3):
		for x in range(cx - 2, cx + 3):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				total += image.get_pixel(x, y)
				count += 1
	if count == 0:
		return Color.GRAY
	var avg := total / count
	avg.a = 1.0
	return avg

# --- Moving ------------------------------------------------------------------------

## Walk through `points` in order, facing the way they go.
func walk(points: PackedVector3Array, then: Callable = Callable()) -> void:
	_path = points
	_then = then
	is_walking = not _path.is_empty()

## Turn the whole body toward a point.
func face(point: Vector3, instant: bool = false) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() < 0.001:
		return
	_target_yaw = atan2(-d.x, -d.z)
	if instant:
		rotation.y = _target_yaw

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _built:
		return

	if is_walking and not _path.is_empty():
		var goal := _path[0]
		var to_goal := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
		var step := walk_speed * delta
		if to_goal.length() <= step:
			global_position = Vector3(goal.x, global_position.y, goal.z)
			_path.remove_at(0)
			if _path.is_empty():
				is_walking = false
				_rest_limbs()
				arrived.emit()
				if _then.is_valid():
					var callback := _then
					_then = Callable()
					callback.call()
		else:
			global_position += to_goal.normalized() * step
			face(goal)
		_walk_cycle(delta)

	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 6.0, 0.0, 1.0))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _built:
		return
	_idle_t += delta
	# Breathing.
	torso.scale.y = 1.0 + sin(_idle_t * TAU * 0.24) * 0.008
	# A little weight-shifting and head drift, unless the body is busy with a tell.
	if not is_walking and Time.get_ticks_msec() / 1000.0 > _busy_until:
		head.rotation.y = lerp(head.rotation.y, sin(_idle_t * 0.37) * 0.05, delta * 2.0)
		head.rotation.x = lerp(head.rotation.x, sin(_idle_t * 0.23) * 0.03, delta * 2.0)
		torso.rotation.z = sin(_idle_t * 0.3) * 0.012
	_blink()

func _blink() -> void:
	if _idle_t < _next_blink:
		return
	var closing := _idle_t - _next_blink < 0.12
	for eye in _eyes:
		eye.scale.y = 0.1 if closing else 1.0
	if not closing:
		_next_blink = _idle_t + randf_range(2.0, 5.5)

func _walk_cycle(delta: float) -> void:
	_walk_phase += delta * walk_speed * 3.4
	var swing := sin(_walk_phase) * 0.42
	thigh_l.rotation.x = swing
	thigh_r.rotation.x = -swing
	shin_l.rotation.x = maxf(0.0, -swing) * -0.6
	shin_r.rotation.x = maxf(0.0, swing) * -0.6
	arm_l.rotation.x = -swing * 0.6
	arm_r.rotation.x = swing * 0.6
	torso.position.y = HIP_Y + absf(cos(_walk_phase)) * 0.018

func _rest_limbs() -> void:
	for limb in [thigh_l, thigh_r, shin_l, shin_r, arm_l, arm_r]:
		limb.rotation.x = 0.0
	arm_l.rotation.z = 0.0
	arm_r.rotation.z = 0.0
	_apply_pose()

# --- Tells ------------------------------------------------------------------------

## Perform a line.
func perform(delivery: int, lead_in: float, speaking: float, exit_point: Vector3) -> void:
	if not _built:
		return
	if _tell_tween and _tell_tween.is_valid():
		_tell_tween.kill()
	current_tell = delivery
	_busy_until = Time.get_ticks_msec() / 1000.0 + lead_in + speaking + 0.3

	var t := create_tween()
	_tell_tween = t
	var D := DialogueLine.Delivery

	match delivery:
		D.CHECKS_EXIT:
			# Eyes to the door before the mouth moves.
			var yaw := clampf(_local_yaw_to(exit_point), -1.35, 1.35)
			t.tween_property(head, "rotation:y", yaw, 0.22).set_trans(Tween.TRANS_SINE)
			t.tween_interval(0.75)
			t.tween_property(head, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
			_talk(t, maxf(speaking - 0.6, 0.4), 0.04)

		D.CHECKS_TIME:
			# Wrist up, eyes down to it, then back.
			t.tween_property(arm_l, "rotation:x", deg_to_rad(-80.0), 0.3)
			t.parallel().tween_property(arm_l, "rotation:z", deg_to_rad(-35.0), 0.3)
			t.parallel().tween_property(head, "rotation:x", deg_to_rad(-28.0), 0.3)
			t.parallel().tween_property(forearm_l, "rotation:x", deg_to_rad(-60.0), 0.3)
			t.tween_interval(0.8)
			t.tween_property(arm_l, "rotation:x", 0.0, 0.35)
			t.parallel().tween_property(forearm_l, "rotation:x", ELBOW_REST, 0.35)
			t.parallel().tween_property(arm_l, "rotation:z", 0.0, 0.35)
			t.parallel().tween_property(head, "rotation:x", 0.0, 0.35)
			_talk(t, maxf(speaking - 0.5, 0.4), 0.04)

		D.HESITANT:
			# Dead still through the silence, a small drop of the head, then an answer that starts with a swallow.
			t.tween_property(head, "rotation:x", deg_to_rad(-9.0), 0.4)
			t.tween_interval(maxf(lead_in - 0.4, 0.1))
			t.tween_property(head, "rotation:x", 0.0, 0.25)
			_talk(t, speaking, 0.03)

		D.GOES_QUIET:
			# Head down, gaze off to one side, and nothing else.
			t.tween_property(head, "rotation:x", deg_to_rad(-22.0), 0.5)
			t.parallel().tween_property(head, "rotation:y", deg_to_rad(18.0), 0.5)
			t.tween_interval(lead_in + speaking)
			t.tween_property(head, "rotation:x", 0.0, 0.6)
			t.parallel().tween_property(head, "rotation:y", 0.0, 0.6)

		D.TOO_FAST:
			# Leans in and answers before the question has quite finished.
			t.tween_property(torso, "rotation:x", deg_to_rad(-7.0), 0.15)
			_talk(t, speaking, 0.07, 4.0)
			t.tween_property(torso, "rotation:x", 0.0, 0.3)

		D.OVER_EXPLAINS:
			# Hands start working.
			var beats := maxi(2, int(speaking * 1.6))
			for i in beats:
				var arm := arm_r if i % 2 == 0 else arm_l
				var fore := forearm_r if i % 2 == 0 else forearm_l
				t.tween_property(arm, "rotation:x", deg_to_rad(-38.0), 0.25)
				t.parallel().tween_property(fore, "rotation:x", deg_to_rad(-55.0), 0.25)
				t.parallel().tween_property(head, "rotation:x", deg_to_rad(4.0), 0.25)
				t.tween_property(arm, "rotation:x", deg_to_rad(-12.0), 0.3)
				t.parallel().tween_property(head, "rotation:x", 0.0, 0.3)
			t.tween_property(arm_l, "rotation:x", 0.0, 0.3)
			t.parallel().tween_property(arm_r, "rotation:x", 0.0, 0.3)
			t.parallel().tween_property(forearm_l, "rotation:x", ELBOW_REST, 0.3)
			t.parallel().tween_property(forearm_r, "rotation:x", ELBOW_REST, 0.3)

		_:
			_talk(t, lead_in + speaking, 0.04)

	t.finished.connect(func() -> void: current_tell = -1)

## Turn the head toward someone, talk for `seconds`, then look back to what you were doing.
func address(point: Vector3, seconds: float) -> void:
	if not _built:
		return
	if _tell_tween and _tell_tween.is_valid():
		_tell_tween.kill()
	_busy_until = Time.get_ticks_msec() / 1000.0 + seconds + 0.6
	var yaw := clampf(_local_yaw_to(point), -1.35, 1.35)
	var t := create_tween()
	_tell_tween = t
	t.tween_property(head, "rotation:y", yaw, 0.35).set_trans(Tween.TRANS_SINE)
	_talk(t, seconds, 0.035)
	t.tween_property(head, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

## A hidden person should not be something you can walk into.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _built:
		collision_layer = 2 if is_visible_in_tree() else 0

## Small nods while speaking.
func _talk(t: Tween, seconds: float, amplitude: float, rate_hz: float = 2.4) -> void:
	var nods := maxi(1, int(seconds * rate_hz))
	var half := 0.5 / rate_hz
	for i in nods:
		t.tween_property(head, "rotation:x", amplitude, half)
		t.tween_property(head, "rotation:x", 0.0, half)

## Head yaw, relative to the body, that points the face at `point`.
func _local_yaw_to(point: Vector3) -> float:
	var local := to_local(point)
	return atan2(-local.x, -local.z)
