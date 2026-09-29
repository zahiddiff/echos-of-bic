extends CanvasLayer
class_name TerminalScreen

## The records terminal's screen.

signal dismissed()

@export var columns: int = 46
@export var header: String = "BIC STUDENT RECORDS  v2.1   (c) 1998"

@onready var output: Label = $Frame/Screen/Column/Output
@onready var entry: LineEdit = $Frame/Screen/Column/Entry
@onready var status: Label = $Frame/Screen/Column/Status

var computer: RecordsComputer

@export var key_sound: AudioStream
@export var error_sound: AudioStream

var _audio: AudioStreamPlayer

func _ready() -> void:
	visible = false
	entry.text_submitted.connect(_on_submitted)
	_audio = AudioStreamPlayer.new()
	_audio.name = "TerminalAudio"
	add_child(_audio)
	# Every keystroke clicks.
	entry.text_changed.connect(func(_t: String) -> void: _play(key_sound))

func attach(new_computer: RecordsComputer) -> void:
	computer = new_computer
	computer.opened.connect(open)
	computer.closed.connect(_on_computer_closed)

func open() -> void:
	visible = true
	_print_lines(PackedStringArray([
		header,
		_rule(),
		"",
		"ENTER STUDENT NUMBER AND PRESS RETURN.",
		"FORMAT: BIC-YY-NNNNNN",
	]))
	status.text = "READY"
	entry.clear()
	entry.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()

func dismiss() -> void:
	if not visible:
		return
	visible = false
	if computer:
		computer.close()
	dismissed.emit()

func _on_computer_closed() -> void:
	visible = false

func _on_submitted(text: String) -> void:
	if computer == null:
		return
	var query := text.strip_edges()
	if query.is_empty():
		return
	var lines := computer.lookup(query)
	_print_lines(_prefixed(lines))
	var found := computer.has_record(query)
	status.text = "RECORD FOUND" if found else "NO RECORD"
	_play(key_sound if found else error_sound)
	entry.clear()
	entry.grab_focus()

func _prefixed(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray([header, _rule(), ""])
	for line in lines:
		out.append(line)
	return out

func _rule() -> String:
	return "=".repeat(columns)

func _print_lines(lines: PackedStringArray) -> void:
	output.text = "\n".join(lines)

func _play(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()
