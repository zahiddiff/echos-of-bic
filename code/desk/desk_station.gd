extends Interactable
class_name DeskStation

## The player's station at the counter.

signal seated(player: Node)
signal stood_up(player: Node)

## Marker3D giving the seated camera position and facing.
@export var seat_marker_path: NodePath = ^"SeatMarker"
@export var transition_time: float = 0.55
@export var stand_prompt: String = "Work the desk"

var is_seated: bool = false

var _player: PlayerController
var _standing_transform: Transform3D
var _standing_pitch: float = 0.0
var _tween: Tween

@onready var seat_marker: Node3D = get_node_or_null(seat_marker_path)

func _ready() -> void:
	prompt_text = stand_prompt

func interact(player: Node) -> void:
	if locked or is_seated:
		return
	if seat_marker == null:
		push_warning("DeskStation '%s' has no seat marker; cannot sit." % name)
		return

	sit(player as PlayerController)
	super.interact(player)

func _unhandled_input(event: InputEvent) -> void:
	# Only while seated, and only if nothing above us (the document viewer) already consumed the key.
	if is_seated and event.is_action_pressed("ui_cancel"):
		stand()
		get_viewport().set_input_as_handled()

func sit(player: PlayerController) -> void:
	if player == null or is_seated:
		return

	_player = player
	_standing_transform = player.global_transform
	_standing_pitch = player.head.rotation.x

	# The player controller owns mouse capture and movement; take both away rather than editing that script.
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	is_seated = true
	_move_player_to(seat_marker.global_position, seat_marker.global_rotation.y,
		seat_marker.global_rotation.x)
	seated.emit(player)

func stand() -> void:
	if not is_seated or _player == null:
		return

	is_seated = false
	var player := _player
	_move_player_to(_standing_transform.origin, _standing_transform.basis.get_euler().y,
		_standing_pitch)

	if _tween:
		_tween.finished.connect(func() -> void: _release(player), CONNECT_ONE_SHOT)
	else:
		_release(player)

	stood_up.emit(player)

func _release(player: PlayerController) -> void:
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _move_player_to(target_position: Vector3, target_yaw: float, target_pitch: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	var from_yaw := _player.rotation.y
	var from_pitch := _player.head.rotation.x

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_player, "global_position", target_position, transition_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Angles are tweened by hand so they take the short way round.
	_tween.tween_method(
		func(t: float) -> void: _player.rotation.y = lerp_angle(from_yaw, target_yaw, t),
		0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(
		func(t: float) -> void: _player.head.rotation.x = lerp_angle(from_pitch, target_pitch, t),
		0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Finish the transition immediately — used by tests and scripted beats.
func settle() -> void:
	if _tween and _tween.is_valid():
		_tween.custom_step(transition_time + 0.01)
