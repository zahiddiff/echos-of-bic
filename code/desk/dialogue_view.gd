extends CanvasLayer
class_name DialogueView

## Subtitles and the optional follow-up questions.

signal line_started(line: DialogueLine)
signal line_finished(line: DialogueLine)
signal follow_up_asked(follow_up: VisitorDialogue.FollowUp)
signal exhausted()

@export var reading_speed: float = 15.0
## Extra pause held after a GOES_QUIET line, on top of its own hold.
@export var silence_padding: float = 0.8

@onready var subtitle: Label = $Subtitle
@onready var speaker_label: Label = $Speaker
@onready var questions: VBoxContainer = $Questions
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var dialogue: VisitorDialogue
var is_playing: bool = false

## Rahat talking over the desk and the visitor answering you are two separate callers into one subtitle layer.
var _pending: Array[Callable] = []
var _pumping: bool = false

var _current: DialogueLine
var _pending_close: bool = false

func _ready() -> void:
	_clear()

## Start a visitor's conversation from the top.
func begin(new_dialogue: VisitorDialogue) -> void:
	await _enqueue(func() -> void: await _begin_now(new_dialogue))

func _begin_now(new_dialogue: VisitorDialogue) -> void:
	dialogue = new_dialogue
	visible = true
	if dialogue and dialogue.opening:
		await play(dialogue.opening)
	_offer_questions()

## Queues `job` and waits for *that* job to finish, so callers can still `await` a line the way they could before the queue existed.
func _enqueue(job: Callable) -> void:
	var state := {"done": false}
	_pending.append(func() -> void:
		await job.call()
		state["done"] = true)
	if not _pumping:
		_pump()
	while not state["done"]:
		await get_tree().process_frame

func _pump() -> void:
	_pumping = true
	while not _pending.is_empty():
		var job: Callable = _pending.pop_front()
		await job.call()
	_pumping = false

## Is anyone still mid-sentence?
func is_busy() -> bool:
	return _pumping or is_playing

## Play a run of plain lines from one speaker, back to back.
func play_sequence(speaker: String, texts: PackedStringArray) -> void:
	await _enqueue(func() -> void: await _play_sequence_now(speaker, texts))

func _play_sequence_now(speaker: String, texts: PackedStringArray) -> void:
	dialogue = null
	visible = true
	_hide_questions()
	for text in texts:
		var line := DialogueLine.new()
		line.speaker = speaker
		line.text = text
		await play(line)
	# Only drop the layer if nobody else is waiting to speak.
	if _pending.is_empty():
		visible = false
	exhausted.emit()

func play(line: DialogueLine) -> void:
	if line == null:
		return
	is_playing = true
	_current = line
	_hide_questions()

	speaker_label.text = line.speaker
	speaker_label.visible = not line.speaker.is_empty()
	subtitle.text = ""
	subtitle.visible = false

	line_started.emit(line)

	# The silence before the answer is part of the answer.
	if line.lead_in > 0.0:
		await get_tree().create_timer(line.lead_in).timeout

	if line.delivery == DialogueLine.Delivery.GOES_QUIET:
		# They say nothing.
		await get_tree().create_timer(line.display_seconds(reading_speed) + silence_padding).timeout
	else:
		subtitle.text = line.text
		subtitle.visible = true
		if line.voice:
			audio_player.stream = line.voice
			audio_player.play()
		await get_tree().create_timer(line.display_seconds(reading_speed)).timeout

	subtitle.visible = false
	is_playing = false
	line_finished.emit(line)

	if _pending_close:
		_pending_close = false
		_finish()

## Ask one of the remaining follow-ups.
func ask(follow_up: VisitorDialogue.FollowUp) -> void:
	if follow_up == null or follow_up.asked or is_playing:
		return
	follow_up.asked = true
	follow_up_asked.emit(follow_up)
	await play(follow_up.answer)
	_offer_questions()

## Let the visitor go without asking anything more.
func wrap_up() -> void:
	if is_playing:
		_pending_close = true
		return
	await _finish()

func _finish() -> void:
	_hide_questions()
	if dialogue and dialogue.closing:
		await play(dialogue.closing)
	visible = false
	exhausted.emit()

func _offer_questions() -> void:
	_hide_questions()
	if dialogue == null:
		return

	var open_questions := dialogue.available_follow_ups()
	if open_questions.is_empty():
		return

	for follow_up in open_questions:
		var button := Button.new()
		button.text = follow_up.question
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: ask(follow_up))
		questions.add_child(button)

	var done := Button.new()
	done.text = "Say nothing more"
	done.alignment = HORIZONTAL_ALIGNMENT_LEFT
	done.modulate = Color(0.75, 0.75, 0.78)
	done.pressed.connect(wrap_up)
	questions.add_child(done)

	questions.visible = true

func _hide_questions() -> void:
	questions.visible = false
	for child in questions.get_children():
		child.queue_free()

func _clear() -> void:
	visible = false
	subtitle.visible = false
	speaker_label.visible = false
	questions.visible = false
