extends CanvasLayer
class_name ShiftReport

## End-of-shift log, then the ending when the run is over.

signal continue_requested()

const FULL_GAME_URL := "https://zahiddiff.github.io/echos-of-bic/"
const ABOUT_URL := "https://zahiddiff.github.io/echos-of-bic/about/"
signal new_run_requested()

var summary: Dictionary = {}
var is_showing: bool = false
## "report" or "ending", once shown.
var mode: String = ""
## Playtest answers for the shift just shown; empty outside playtest mode.
var feedback: Dictionary = {}

var _tension: int = 0
var _tension_buttons: Array[Button] = []
var _fake_field: LineEdit
var _confusing_field: LineEdit

var _shade: ColorRect
var _panel: PanelContainer
var _body: VBoxContainer

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := UiKit.fill(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_shade = UiKit.fill(ColorRect.new()) as ColorRect
	_shade.color = Color(0.02, 0.02, 0.025, 1.0)
	root.add_child(_shade)
	var centre := UiKit.fill(CenterContainer.new())
	root.add_child(centre)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	centre.add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_body)

## `data`: shift, training, reason, seen, total, approved, rejected, flagged, strikes_left, clock_out, run_over.
func show_report(data: Dictionary) -> void:
	summary = data
	is_showing = true
	mode = "report"
	_clear()
	var reason: int = data.get("reason", ShiftRunner.EndReason.QUEUE_FINISHED)
	var shift: int = data.get("shift", 1)

	_body.add_child(UiKit.label("SHIFT LOG  ·  FRONT DESK", 12, UiKit.FAINT))
	var title := "Shift %d complete" % shift
	var line := "The queue is empty. You can go home."
	match reason:
		ShiftRunner.EndReason.INCIDENT:
			title = "Shift %d ended early" % shift
			line = "Something got past the desk tonight. You were sent home."
		ShiftRunner.EndReason.SENT_HOME:
			title = "Shift %d ended early" % shift
			line = "You were sent home for calling security on people who had done nothing."
	if data.get("training", false) and reason == ShiftRunner.EndReason.QUEUE_FINISHED:
		title = "Training shift complete"
		line = "Rahat signs your sheet. From tomorrow the queue is yours."
	match int(data.get("finale", Finale.Outcome.NONE)):
		Finale.Outcome.STOPPED:
			title = "Lockdown"
			line = "You called it in. Security stopped them before they reached the meeting room."
		Finale.Outcome.REACHED:
			title = "Lockdown"
			line = "They reached the meeting room before security reached them."
	_body.add_child(UiKit.label(title, 28))
	_body.add_child(UiKit.label(line, 15, UiKit.MUTED))
	_body.add_child(_spacer(6))
	_body.add_child(UiKit.rule())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	_row(grid, "Visitors seen", "%d of %d" % [data.get("seen", 0), data.get("total", 0)])
	_row(grid, "Approved", str(data.get("approved", 0)))
	_row(grid, "Rejected", str(data.get("rejected", 0)))
	_row(grid, "Security called", str(data.get("flagged", 0)))
	_row(grid, "Clocked out", str(data.get("clock_out", "--:--")))
	_body.add_child(grid)
	_body.add_child(UiKit.rule())

	var strikes := HBoxContainer.new()
	strikes.add_theme_constant_override("separation", 6)
	var key := UiKit.label("Strikes left", 15, UiKit.MUTED)
	key.custom_minimum_size = Vector2(160, 0)
	strikes.add_child(key)
	var left: int = data.get("strikes_left", GameState.MAX_STRIKES)
	for i in GameState.MAX_STRIKES:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22, 10)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = UiKit.ACCENT if i < left else Color(0.2, 0.2, 0.22)
		strikes.add_child(pip)
	_body.add_child(strikes)
	_body.add_child(_spacer(10))

	feedback = {}
	_body.add_theme_constant_override("separation", 7 if PlaytestLog.questionnaire else 10)
	if PlaytestLog.questionnaire:
		_add_questions()

	var run_over: bool = data.get("run_over", false)
	var next := UiKit.button("Continue" if run_over else "Clock out")
	next.pressed.connect(func() -> void:
		if PlaytestLog.questionnaire:
			feedback = {
				"tension": _tension,
				"felt_fake": _fake_field.text.strip_edges(),
				"confusing": _confusing_field.text.strip_edges(),
			}
		continue_requested.emit())
	_body.add_child(next)
	_reveal(next)

## The last screen of a run.
func show_ending(which: GameState.Ending, lines: PackedStringArray) -> void:
	is_showing = true
	mode = "ending"
	_clear()
	var heading := {
		GameState.Ending.FIRED: "Let go",
		GameState.Ending.STANDARD: "Contract complete",
		GameState.Ending.TRUE_END: "Nothing got past you",
	}
	_body.add_child(UiKit.label("END OF EMPLOYMENT RECORD", 12, UiKit.FAINT))
	_body.add_child(UiKit.label(heading.get(which, "The end"), 30,
		UiKit.DANGER if which == GameState.Ending.FIRED else UiKit.INK))
	_body.add_child(UiKit.rule())
	var fades: Array[Control] = []
	for text in lines:
		var l := UiKit.label(text, 16, UiKit.MUTED)
		l.modulate.a = 0.0
		_body.add_child(l)
		fades.append(l)
	_body.add_child(_spacer(10))
	var again := UiKit.button("Start a new run")
	again.modulate.a = 0.0
	again.pressed.connect(func() -> void: new_run_requested.emit())
	_body.add_child(again)
	fades.append(again)
	if PlaytestLog.questionnaire:
		var save_button := UiKit.button("Save playtest log", false)
		save_button.modulate.a = 0.0
		save_button.pressed.connect(func() -> void: save_button.text = "Saved: %s" % PlaytestLog.export_log())
		_body.add_child(save_button)
		fades.append(save_button)

	_reveal(null)
	var t := create_tween()
	t.tween_interval(0.8)
	for control in fades:
		t.tween_property(control, "modulate:a", 1.0, 0.9)
		t.tween_interval(0.9)
	t.tween_callback(again.grab_focus)

## Two short questions, answered before clocking out. Nothing here is required.
func _add_questions() -> void:
	var scale := HBoxContainer.new()
	scale.add_theme_constant_override("separation", 6)
	_tension = 0
	_tension_buttons.clear()
	for value in range(1, 6):
		var b := UiKit.button(str(value), false)
		b.custom_minimum_size = Vector2(40, 32)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.toggle_mode = true
		b.pressed.connect(_pick_tension.bind(value))
		scale.add_child(b)
		_tension_buttons.append(b)
	var ends := UiKit.label("How tense was that?  1 calm, 5 on edge", 13, UiKit.MUTED)
	ends.autowrap_mode = TextServer.AUTOWRAP_OFF
	ends.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	scale.add_child(gap)
	scale.add_child(ends)
	_body.add_child(scale)
	_fake_field = _field("Did anything feel fake or out of place? (optional)")
	_confusing_field = _field("Was anything confusing? (optional)")

func _pick_tension(value: int) -> void:
	_tension = value
	for i in _tension_buttons.size():
		_tension_buttons[i].button_pressed = i == value - 1
		_tension_buttons[i].modulate = Color(1.5, 1.3, 0.8) if i == value - 1 else Color.WHITE

func _field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0, 32)
	field.add_theme_font_size_override("font_size", 14)
	_body.add_child(field)
	return field

## Where the demo stops: what the run looked like, and where the rest of it is.
func show_demo_end(strikes_left: int, incidents: int) -> void:
	is_showing = true
	mode = "demo_end"
	_clear()
	_body.add_theme_constant_override("separation", 10)
	_body.add_child(UiKit.label("END OF THE DEMO", 12, UiKit.FAINT))
	_body.add_child(UiKit.label("Three nights at the desk", 30))
	_body.add_child(UiKit.label("The full game runs eight. The queue gets longer, the building gets quieter, and it remembers what you let through.", 15, UiKit.MUTED))
	_body.add_child(UiKit.rule())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_row(grid, "Strikes left", "%d of %d" % [strikes_left, GameState.MAX_STRIKES])
	_row(grid, "Incidents on your watch", str(incidents))
	_body.add_child(grid)
	_body.add_child(UiKit.rule())
	_body.add_child(_spacer(4))
	var full := UiKit.button("Keep playing the development build")
	full.pressed.connect(func() -> void: OS.shell_open(FULL_GAME_URL))
	_body.add_child(full)
	var follow := UiKit.button("About the game", false)
	follow.pressed.connect(func() -> void: OS.shell_open(ABOUT_URL))
	_body.add_child(follow)
	var again := UiKit.button("Start the demo again", false)
	again.pressed.connect(func() -> void: new_run_requested.emit())
	_body.add_child(again)
	if PlaytestLog.questionnaire:
		var save_button := UiKit.button("Save playtest log", false)
		save_button.pressed.connect(func() -> void: save_button.text = "Saved: %s" % PlaytestLog.export_log())
		_body.add_child(save_button)
	_reveal(full)

func _reveal(focus: Control) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shade.modulate.a = 0.0
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_shade, "modulate:a", 0.94, 1.2)
	t.tween_property(_panel, "modulate:a", 1.0, 0.6)
	if focus:
		t.tween_callback(focus.grab_focus)

func _row(grid: GridContainer, key: String, value: String) -> void:
	var k := UiKit.label(key, 15, UiKit.MUTED)
	k.custom_minimum_size = Vector2(160, 0)
	grid.add_child(k)
	var v := UiKit.label(value, 15)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)

func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
