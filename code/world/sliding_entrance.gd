extends Node3D
class_name SlidingEntrance

## The front entrance: automatic sliding doors, convenience store style.

@export var slide_distance: float = 1.0
@export var slide_time: float = 0.7
@export var close_delay: float = 1.4
@export var open_sound: AudioStream
@export var close_sound: AudioStream
## The two-note door chime.
@export var chime_sound: AudioStream
@export var chime_enabled: bool = true

@onready var left_panel: Node3D = $LeftPanel
@onready var right_panel: Node3D = $RightPanel
@onready var trigger: Area3D = $Trigger
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var close_timer: Timer = $CloseTimer

signal opened()
signal closed()

var is_open: bool = false

var _left_closed_z: float = 0.0
var _right_closed_z: float = 0.0
var _left_tween: Tween
var _right_tween: Tween
var _occupants: int = 0

var _chime: AudioStreamPlayer3D

func _ready() -> void:
	_chime = AudioStreamPlayer3D.new()
	_chime.name = "Chime"
	_chime.position = Vector3(-0.3, 2.4, 0.0)
	add_child(_chime)
	_left_closed_z = left_panel.position.z
	_right_closed_z = right_panel.position.z

	close_timer.wait_time = close_delay
	close_timer.one_shot = true
	close_timer.timeout.connect(_on_close_timer_timeout)

	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)

func _on_body_entered(_body: Node3D) -> void:
	_occupants += 1
	close_timer.stop()
	if not is_open:
		_set_open(true)

func _on_body_exited(_body: Node3D) -> void:
	_occupants = max(_occupants - 1, 0)
	# Body_exited also fires while the scene is being torn down, when the timer is already out of the tree.
	if _occupants == 0 and is_open and close_timer.is_inside_tree():
		close_timer.start()

func _on_close_timer_timeout() -> void:
	if _occupants == 0:
		_set_open(false)

func _set_open(value: bool) -> void:
	is_open = value

	var travel := slide_distance if is_open else 0.0
	_left_tween = _slide(left_panel, _left_tween, _left_closed_z - travel)
	_right_tween = _slide(right_panel, _right_tween, _right_closed_z + travel)

	var stream := open_sound if is_open else close_sound
	if stream:
		audio_player.stream = stream
		audio_player.play()

	if is_open and chime_enabled and chime_sound:
		_chime.stream = chime_sound
		_chime.play()

	if is_open:
		opened.emit()
	else:
		closed.emit()

func _slide(panel: Node3D, tween: Tween, target_z: float) -> Tween:
	if tween and tween.is_valid():
		tween.kill()
	var new_tween := create_tween()
	new_tween.tween_property(panel, "position:z", target_z, slide_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return new_tween
