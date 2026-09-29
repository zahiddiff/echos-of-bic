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

const DEFAULT_HINT := "Drag the papers  ·  Magnifier over a photo  ·  Click the stamp, slip or radio to decide  ·  Esc to stand"
const INK_DARK := Color(0.12, 0.11, 0.1)
const INK_SOFT := Color(0.42, 0.4, 0.36)

## The desk reference: what counts as valid tonight.
var rulebook_sheet: DraggablePaper
var _rules_box: VBoxContainer
var _mark: Label

## What was fetched from the back room, to compare against the form.
var item_paper: DraggablePaper
var _item_kind: Label
var _item_title: Label
var _item_name: Label
var _item_number: Label
var _collect_value: Label
var _collect_row: Control

func _ready() -> void:
	_home_positions[request_form] = request_form.position
	_home_positions[id_card] = id_card.position
	_home_positions[magnifier] = magnifier.position
	# Out of the way of the ID card, so both photos can be compared side by side.
	magnifier.position = Vector2(650, 205)
	_home_positions[magnifier] = magnifier.position
	_build_rulebook_sheet()
	_home_positions[rulebook_sheet] = rulebook_sheet.position
	_build_item_paper()
	_home_positions[item_paper] = item_paper.position
	_build_collect_row()
	hint_label.text = DEFAULT_HINT

	_audio = AudioStreamPlayer.new()
	_audio.name = "PaperAudio"
	add_child(_audio)
	for paper: DraggablePaper in [request_form, id_card, rulebook_sheet, item_paper]:
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

	_mark.visible = false
	show_collection(request)
	reset_layout()

## Physical tasks: waiting in the back room, or fetched and on the desk.
func show_collection(req: VisitorRequest) -> void:
	var needed := req != null and req.needs_collection()
	_collect_row.visible = needed
	item_paper.visible = needed and req.collected
	if not needed:
		return
	var parcel := TaskPool.collection_kind(req.task_id) == "parcel"
	if req.collected:
		_collect_value.text = "Collected. Check it against this form."
		_collect_value.modulate = Color.WHITE
	else:
		_collect_value.text = "%s. Waiting on the %s in the print room." % [
			TaskPool.collection_label(req.task_id), "shelf" if parcel else "printer"]
		_collect_value.modulate = Color(0.62, 0.34, 0.2)
	_item_kind.text = "MAILROOM SHELF" if parcel else "PRINT ROOM"
	_item_title.text = req.collected_label()
	_item_name.text = req.collected_name()
	_item_number.text = req.id_number

## What the rules are tonight. During training only what Rahat has covered so far.
func show_rulebook(book: Rulebook) -> void:
	for child in _rules_box.get_children():
		_rules_box.remove_child(child)
		child.queue_free()
	_rules_box.add_child(_paper_label("Today  %s" % book.current_date, 13, INK_DARK))
	var rules: Array = book.enabled_rules if not book.enabled_rules.is_empty() else Rulebook.RULE_TITLES.keys()
	for rule in Rulebook.RULE_TITLES.keys():
		if not rules.has(rule):
			continue
		var line := ""
		match rule:
			Rulebook.Rule.NAME_MATCH:
				line = "Name on the form matches the ID card."
			Rulebook.Rule.ID_FORMAT:
				line = "ID reads BIC-YY-NNNNNN, six digits. Year %02d to %02d." % [book.min_enrollment_year, book.max_enrollment_year]
			Rulebook.Rule.COLLEGE_CODE:
				line = "College code is one of: %s" % "  ".join(book.valid_college_codes)
			Rulebook.Rule.PHOTO_MATCH:
				line = "The ID photo is the person at the desk."
			Rulebook.Rule.VALIDITY_WINDOW:
				line = "Issue date plus the window has not passed today."
			Rulebook.Rule.PRIOR_STAMP:
				line = "If a prior approval is required, it is there."
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_paper_label(str(Rulebook.RULE_TITLES[rule]).to_upper(), 10, INK_SOFT))
		row.add_child(_paper_label(line, 13, INK_DARK))
		_rules_box.add_child(row)
	if rules.size() < Rulebook.RULE_TITLES.size():
		_rules_box.add_child(_paper_label("More rules are added as you are trained.", 11, INK_SOFT))

## Ink on the form once a decision is made.
func stamp_mark(approved: bool) -> void:
	_mark.text = "APPROVED" if approved else "REJECTED"
	var ink := Color(0.16, 0.45, 0.24) if approved else Color(0.66, 0.16, 0.14)
	_mark.add_theme_color_override("font_color", ink)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = ink
	box.set_border_width_all(3)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(8)
	_mark.add_theme_stylebox_override("normal", box)
	_mark.visible = true
	_mark.pivot_offset = _mark.size * 0.5
	_mark.scale = Vector2(1.6, 1.6)
	_mark.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_mark, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_mark, "modulate:a", 0.88, 0.08)

func show_hint(text: String) -> void:
	hint_label.text = text

func clear_hint() -> void:
	hint_label.text = DEFAULT_HINT

func _build_rulebook_sheet() -> void:
	rulebook_sheet = DraggablePaper.new()
	rulebook_sheet.name = "Rulebook"
	rulebook_sheet.lift_tilt = 1.2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.91, 0.8)
	style.border_color = Color(0.68, 0.65, 0.54)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(3, 5)
	style.set_content_margin_all(16)
	rulebook_sheet.add_theme_stylebox_override("panel", style)
	rulebook_sheet.custom_minimum_size = Vector2(300, 0)
	rulebook_sheet.position = Vector2(950, 418)
	rulebook_sheet.rotation_degrees = -1.5
	surface.add_child(rulebook_sheet)
	surface.move_child(rulebook_sheet, magnifier.get_index())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rulebook_sheet.add_child(column)
	column.add_child(_paper_label("DESK RULES", 11, INK_SOFT))
	var rule := ColorRect.new()
	rule.color = Color(0.6, 0.58, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	_rules_box = VBoxContainer.new()
	_rules_box.add_theme_constant_override("separation", 6)
	_rules_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rules_box)

	_mark = Label.new()
	_mark.name = "DecisionMark"
	_mark.add_theme_font_size_override("font_size", 34)
	_mark.rotation_degrees = -14.0
	_mark.position = Vector2(170, 330)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.visible = false
	# The form is a container; a plain Control inside it lets the mark float over the rows.
	var layer := Control.new()
	layer.name = "MarkLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	request_form.add_child(layer)
	layer.add_child(_mark)

func _build_item_paper() -> void:
	item_paper = DraggablePaper.new()
	item_paper.name = "Collected"
	item_paper.lift_tilt = 1.2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.97, 0.95)
	style.border_color = Color(0.7, 0.7, 0.68)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(3, 5)
	style.set_content_margin_all(14)
	item_paper.add_theme_stylebox_override("panel", style)
	item_paper.custom_minimum_size = Vector2(300, 0)
	item_paper.position = Vector2(572, 28)
	item_paper.rotation_degrees = 1.2
	item_paper.visible = false
	surface.add_child(item_paper)
	surface.move_child(item_paper, magnifier.get_index())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_paper.add_child(column)
	_item_kind = _paper_label("", 10, INK_SOFT)
	column.add_child(_item_kind)
	_item_title = _paper_label("", 18, INK_DARK)
	column.add_child(_item_title)
	column.add_child(_paper_label("ISSUED TO", 10, INK_SOFT))
	_item_name = _paper_label("", 16, INK_DARK)
	column.add_child(_item_name)
	_item_number = _paper_label("", 14, INK_DARK)
	column.add_child(_item_number)

func _build_collect_row() -> void:
	var rows: VBoxContainer = $Surface/RequestForm/Sheet/Rows
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var key := Label.new()
	key.text = "FROM THE BACK ROOM"
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", INK_SOFT)
	row.add_child(key)
	_collect_value = Label.new()
	_collect_value.add_theme_font_size_override("font_size", 15)
	_collect_value.add_theme_color_override("font_color", INK_DARK)
	_collect_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collect_value.custom_minimum_size = Vector2(360, 0)
	row.add_child(_collect_value)
	rows.add_child(row)
	_collect_row = row
	row.visible = false

func _paper_label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(268, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

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
		hint_label.text = DEFAULT_HINT
		return
	var subject_name := "the ID photo" if subject == id_photo else "the visitor"
	hint_label.text = "Magnifying %s" % subject_name
	photo_inspected.emit(subject_name)

func _play(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()
