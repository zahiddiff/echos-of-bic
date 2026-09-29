extends CanvasLayer
class_name DocumentViewer

## The desk paperwork view.

signal closed()
signal photo_inspected(subject_name: String)

@onready var surface: Control = $Surface
@onready var request_form: DraggablePaper = $Surface/RequestForm
@onready var id_card: DraggablePaper = $Surface/IdCard
@onready var magnifier: Magnifier = $Surface/Magnifier
@onready var id_photo: TextureRect = $Surface/IdCard/Card/Photo
@onready var visitor_photo: TextureRect = $Surface/VisitorPanel/Column/Photo
@onready var hint_label: Label = $Hint

var request: VisitorRequest

@export var pickup_sound: AudioStream
@export var drop_sound: AudioStream

var _audio: AudioStreamPlayer

var _home_positions: Dictionary = {}

func _ready() -> void:
	_home_positions[request_form] = request_form.position
	_home_positions[id_card] = id_card.position
	_home_positions[magnifier] = magnifier.position

	_audio = AudioStreamPlayer.new()
	_audio.name = "PaperAudio"
	add_child(_audio)
	for paper: DraggablePaper in [request_form, id_card]:
		paper.picked_up.connect(func(_p: DraggablePaper) -> void: _play(pickup_sound))
		paper.dropped.connect(func(_p: DraggablePaper) -> void: _play(drop_sound))

	magnifier.add_subject(id_photo)
	magnifier.add_subject(visitor_photo)
	magnifier.subject_changed.connect(_on_magnifier_subject_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## Fill the papers in from a visitor's request.
func show_request(new_request: VisitorRequest) -> void:
	request = new_request
	visible = true

	_set_value("Task", request.task_label)
	_set_value("Name", request.form_name)
	_set_value("College", request.college_code)
	_set_value("Issued", request.issue_date)
	_set_value("Window", "%d days from issue" % request.validity_days)

	var stamp_box: Label = $Surface/RequestForm/Sheet/Rows/RowStamp/Value
	if request.requires_prior_stamp:
		stamp_box.text = "PRIOR APPROVAL SEEN" if request.has_prior_stamp else "— blank —"
		stamp_box.modulate = Color.WHITE if request.has_prior_stamp else Color(0.62, 0.28, 0.24)
	else:
		stamp_box.text = "not required"
		stamp_box.modulate = Color(0.45, 0.42, 0.38)

	$Surface/IdCard/Card/Details/CardName.text = request.id_name
	$Surface/IdCard/Card/Details/CardNumber.text = request.id_number
	$Surface/VisitorPanel/Column/Caption.text = request.visitor_name

	id_photo.texture = request.id_photo
	visitor_photo.texture = request.visitor_portrait

	reset_layout()

func reset_layout() -> void:
	for node: Control in _home_positions:
		if node is DraggablePaper:
			(node as DraggablePaper).reset_to(_home_positions[node])
		else:
			node.position = _home_positions[node]

func close() -> void:
	visible = false
	closed.emit()

func _set_value(row: String, value: String) -> void:
	var label: Label = $Surface/RequestForm/Sheet/Rows.get_node("Row%s/Value" % row)
	label.text = value if not value.is_empty() else "—"

func _on_magnifier_subject_changed(subject: TextureRect) -> void:
	if subject == null:
		hint_label.text = "Drag the papers  ·  Drag the magnifier over a photo  ·  Esc to step back"
		return
	var subject_name := "the ID photo" if subject == id_photo else "the visitor"
	hint_label.text = "Magnifying %s" % subject_name
	photo_inspected.emit(subject_name)

func _play(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()
