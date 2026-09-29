extends Interactable
class_name DeskRadio

## The desk radio.

signal call_started(document: Node)
signal call_completed(document: Node)

@export var call_seconds: float = 16.0
@export var calling_prompt: String = "Waiting for security…"
@export var static_sound: AudioStream
@export var pickup_sound: AudioStream
## Squelch and the end-of-transmission beep.
@export var done_sound: AudioStream

var _oneshot: AudioStreamPlayer3D

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var call_timer: Timer = $CallTimer

var is_calling: bool = false
var current_document: Node = null

var _idle_prompt: String = ""

func _ready() -> void:
	_oneshot = AudioStreamPlayer3D.new()
	_oneshot.name = "RadioOneShot"
	add_child(_oneshot)
	_idle_prompt = prompt_text
	call_timer.one_shot = true
	call_timer.wait_time = call_seconds
	call_timer.timeout.connect(_on_call_finished)

func interact(player: Node) -> void:
	if locked or is_calling or current_document == null:
		return

	is_calling = true
	prompt_text = calling_prompt

	if static_sound:
		audio_player.stream = static_sound
		audio_player.play()

	_play_oneshot(pickup_sound)
	call_started.emit(current_document)
	call_timer.start()

	super.interact(player)

func load_document(document: Node) -> void:
	current_document = document

func _on_call_finished() -> void:
	var document := current_document
	current_document = null
	is_calling = false
	prompt_text = _idle_prompt
	if audio_player.playing:
		audio_player.stop()
	_play_oneshot(done_sound)
	call_completed.emit(document)

## Cut the call short — for the shift ending under the player mid-call.
func abort() -> void:
	if not is_calling:
		return
	call_timer.stop()
	is_calling = false
	prompt_text = _idle_prompt
	if audio_player.playing:
		audio_player.stop()

func _play_oneshot(stream: AudioStream) -> void:
	if stream == null or _oneshot == null:
		return
	_oneshot.stream = stream
	_oneshot.play()
