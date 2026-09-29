extends Node

## Tests the document viewer: paperwork renders, sheets drag, and the magnifier picks up whichever photo it is over.
## Run: godot --headless --path <project> res://tools/desk_test.tscn

const VIEWER := "res://scenes/desk/document_viewer.tscn"

var _failures := 0
var _out_dir := ""
var _viewer: DocumentViewer

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	_run()

func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)

func _ok(message: String) -> void:
	print("  ok    %s" % message)

func _expect(condition: bool, message: String) -> void:
	if condition:
		_ok(message)
	else:
		_fail(message)

## A visitor whose ID photo genuinely is them.
func _matching_request() -> VisitorRequest:
	var request := VisitorRequest.new()
	request.visitor_name = "Mahin Rahman"
	request.form_name = "Mahin Rahman"
	request.id_name = "Mahin Rahman"
	request.id_number = "BIC-24-018342"
	request.college_code = "ENG"
	request.task_label = "Transcript printing"
	request.issue_date = "2026-08-01"
	request.validity_days = 90
	request.requires_prior_stamp = false
	request.photo_matches = true

	var face := PortraitFactory.traits_for(20260917)
	request.id_photo = PortraitFactory.render(face, Vector2i(240, 300))
	request.visitor_portrait = PortraitFactory.render(face, Vector2i(240, 300))
	return request

## Same visitor, but the card's photo is somebody very slightly different.
func _mismatched_request() -> VisitorRequest:
	var request := _matching_request()
	request.visitor_name = "Aarav Chowdhury"
	request.form_name = "Aarav Chowdhury"
	request.id_name = "Aarav Chowdhury"
	request.id_number = "BIC-25-771204"
	request.college_code = "BUS"
	request.photo_matches = false
	request.requires_prior_stamp = true
	request.has_prior_stamp = false

	var face := PortraitFactory.traits_for(777)
	request.visitor_portrait = PortraitFactory.render(face, Vector2i(240, 300))
	request.id_photo = PortraitFactory.render(
		PortraitFactory.variant_of(face, 99, 0.65), Vector2i(240, 300))
	return request

func _run() -> void:
	print("Desk test")

	_viewer = load(VIEWER).instantiate()
	add_child(_viewer)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- Rendering ---------------------------------------------------------
	print("\n Paperwork renders")
	var request := _matching_request()
	_viewer.show_request(request)
	await get_tree().process_frame

	var task_value: Label = _viewer.get_node("Surface/RequestForm/Sheet/Rows/RowTask/Value")
	var name_value: Label = _viewer.get_node("Surface/RequestForm/Sheet/Rows/RowName/Value")
	var stamp_value: Label = _viewer.get_node("Surface/RequestForm/Sheet/Rows/RowStamp/Value")
	_expect(task_value.text == request.task_label, "request type printed on the form")
	_expect(name_value.text == request.form_name, "form name printed")
	_expect(stamp_value.text == "not required", "stamp row reads \"not required\" when it isn't")
	_expect(_viewer.get_node("Surface/IdCard/Card/Details/CardNumber").text == request.id_number,
		"ID number printed on the card")
	_expect(_viewer.id_photo.texture != null, "ID card carries a photo")
	_expect(_viewer.visitor_photo.texture != null, "the visitor has a face to compare against")

	# --- Dragging ----------------------------------------------------------
	print("\n The papers are physical")
	var card := _viewer.id_card
	var start := card.position
	card._begin_drag(Vector2(40, 30))
	_expect(card.is_held, "pressing on the ID card picks it up")

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(40 - 120, 30 - 90)
	card._gui_input(motion)
	await get_tree().process_frame
	_expect(card.position != start,
		"dragging moves it (%s -> %s)" % [start, card.position])

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	card._input(release)
	_expect(not card.is_held, "releasing puts it down")

	var form := _viewer.request_form
	form._begin_drag(Vector2(20, 20))
	_expect(form.get_index() > card.get_index(),
		"the sheet you touched last sits on top of the pile")
	form._end_drag()

	# --- Magnifier ---------------------------------------------------------
	print("\n Magnifier")
	var magnifier := _viewer.magnifier
	_viewer.reset_layout()
	await get_tree().process_frame

	_expect(not magnifier.lens.visible, "the lens is blank over bare desk")

	_centre_magnifier_on(_viewer.id_photo)
	_expect(magnifier.active_subject() == _viewer.id_photo, "over the ID photo it reads the card")
	_expect(magnifier.lens.visible, "the lens shows something")
	_expect(magnifier.lens.texture == _viewer.id_photo.texture, "and it is the card's photo")
	_expect(_viewer.hint_label.text.contains("ID photo"), "the hint names what is under the lens")

	_centre_magnifier_on(_viewer.visitor_photo)
	_expect(magnifier.active_subject() == _viewer.visitor_photo,
		"over the visitor it reads the person, not the paperwork")
	_expect(magnifier.lens.texture == _viewer.visitor_photo.texture, "and shows their face")

	magnifier.position = Vector2(40, 620)
	magnifier._refresh()
	_expect(magnifier.active_subject() == null, "moved away, the lens goes blank again")

	# --- Photos actually differ --------------------------------------------
	print("\n Rule 4 is judgeable by eye")
	var mismatched := _mismatched_request()
	_expect(_image_difference(mismatched.id_photo, mismatched.visitor_portrait) > 0.0,
		"a mismatched ID photo is not pixel-identical to the visitor")
	_expect(_image_difference(request.id_photo, request.visitor_portrait) == 0.0,
		"a matching ID photo is identical to the visitor")

	var book := Rulebook.new()
	book.current_date = "2026-09-17"
	_expect(book.passes(request), "the matching visitor's paperwork is clean")
	var broken := book.violations(mismatched)
	_expect(broken.size() == 2,
		"the mismatched visitor breaks exactly two rules (got %d)" % broken.size())

	# --- Closing -----------------------------------------------------------
	print("\n Closing")
	var closed := [false]
	_viewer.closed.connect(func() -> void: closed[0] = true)
	_viewer.close()
	_expect(closed[0] and not _viewer.visible, "close() hides the viewer and reports it")

	if not _out_dir.is_empty():
		await _screenshots(request, mismatched)

	print("")
	if _failures == 0:
		print("DESK TEST PASSED")
	else:
		print("DESK TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _centre_magnifier_on(subject: TextureRect) -> void:
	var magnifier := _viewer.magnifier
	var target := subject.global_position + subject.size * 0.5
	magnifier.position += target - magnifier.lens_centre()
	magnifier._refresh()

## 0.0 when identical.
func _image_difference(a: Texture2D, b: Texture2D) -> float:
	var ia := a.get_image()
	var ib := b.get_image()
	if ia.get_size() != ib.get_size():
		return 1.0
	var total := 0.0
	var samples := 0
	for y in range(0, ia.get_height(), 4):
		for x in range(0, ia.get_width(), 4):
			var ca := ia.get_pixel(x, y)
			var cb := ib.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			samples += 1
	return total / maxf(samples, 1)

func _screenshots(matching: VisitorRequest, mismatched: VisitorRequest) -> void:
	_viewer.show_request(matching)
	await _shot("20-document-viewer.png")

	_centre_magnifier_on(_viewer.id_photo)
	await _shot("21-magnifier-on-id-photo.png")

	_viewer.show_request(mismatched)
	_viewer.id_card.position += Vector2(-180, -150)
	_centre_magnifier_on(_viewer.visitor_photo)
	await _shot("22-mismatch-magnifier-on-visitor.png")

func _shot(file_name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_out_dir.path_join(file_name))
	print("  shot  %s%s" % [file_name, "" if err == OK else " FAILED"])
