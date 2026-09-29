extends Interactable
class_name Door

## Hinged internal door.

@export var open_angle_degrees: float = -90.0
@export var swing_time: float = 0.6
@export var open_prompt: String = "Open the door"
@export var close_prompt: String = "Close the door"
@export var starts_open: bool = false

## Fires when a locked door is tried.
signal refused(player: Node)
signal opened()
signal closed()

var is_open: bool = false

var _closed_yaw: float = 0.0
var _tween: Tween

@export_group("Sound")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
## The handle rattle when it will not give.
@export var locked_sound: AudioStream

var _audio: AudioStreamPlayer3D

func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "DoorAudio"
	_audio.position = Vector3(0.5, 1.0, 0.0)
	add_child(_audio)
	_closed_yaw = rotation.y
	if starts_open:
		_set_open(true, true)
	else:
		_set_open(false, true)

func interact(player: Node) -> void:
	if locked:
		_play(locked_sound)
		refused.emit(player)
		return

	_set_open(not is_open, false)
	_play(open_sound if is_open else close_sound)

	super.interact(player)

## Grant access to a door that started locked (shift scripting, task unlocks).
func unlock() -> void:
	locked = false

func lock() -> void:
	locked = true
	if is_open:
		_set_open(false, false)

func _set_open(value: bool, instant: bool) -> void:
	is_open = value
	prompt_text = close_prompt if is_open else open_prompt

	var target_yaw := _closed_yaw
	if is_open:
		target_yaw += deg_to_rad(open_angle_degrees)

	if _tween and _tween.is_valid():
		_tween.kill()

	if instant:
		rotation.y = target_yaw
	else:
		_tween = create_tween()
		_tween.tween_property(self, "rotation:y", target_yaw, swing_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if is_open:
		opened.emit()
	else:
		closed.emit()

func _play(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()
