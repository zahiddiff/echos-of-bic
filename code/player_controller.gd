extends CharacterBody3D
class_name PlayerController

## Echoes of BIC — First-Person Player Controller
## Attach this to a CharacterBody3D. Expected child nodes:
##   - CollisionShape3D (capsule, matching a standing human)
##   - Head (Node3D) -> Camera3D
##   - Head/Camera3D/InteractRay (RayCast3D, pointing forward)

@export_group("Movement")
@export var walk_speed: float = 3.2
@export var acceleration: float = 10.0
@export var gravity: float = 9.8

@export_group("Look")
@export var mouse_sensitivity: float = 0.12
@export var look_up_limit: float = 85.0
@export var look_down_limit: float = -85.0

@export_group("Interact")
@export var interact_distance: float = 2.2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

var _current_focus: Node = null

signal focus_changed(interactable: Node) # emitted with null when nothing is focused
signal interacted(interactable: Node)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interact_ray.target_position = Vector3(0, 0, -interact_distance)
	interact_ray.enabled = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative)

	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()

	if event.is_action_pressed("interact"):
		_try_interact()

func _apply_look(mouse_delta: Vector2) -> void:
	# Horizontal look rotates the whole body; vertical look rotates the head only.
	rotate_y(deg_to_rad(-mouse_delta.x * mouse_sensitivity))

	var new_pitch := head.rotation_degrees.x - mouse_delta.y * mouse_sensitivity
	new_pitch = clamp(new_pitch, look_down_limit, look_up_limit)
	head.rotation_degrees.x = new_pitch

func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_apply_movement(delta)
	_update_focus()

func _apply_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_velocity := move_dir * walk_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()

func _update_focus() -> void:
	# Every frame, check what the player is currently looking at within interact range.
	var new_focus: Node = null
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		if collider and collider.has_method("get_interactable"):
			new_focus = collider.get_interactable()
		elif collider is Interactable:
			new_focus = collider

	if new_focus != _current_focus:
		_current_focus = new_focus
		focus_changed.emit(_current_focus)

func _try_interact() -> void:
	if _current_focus and _current_focus.has_method("interact"):
		_current_focus.interact(self)
		interacted.emit(_current_focus)
