extends CanvasLayer
class_name PauseMenu

## Shown whenever the mouse is released away from the desk.

signal resumed()
signal quit_requested()

var is_open: bool = false

var _subtitle: Label
var _resume: Button

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := UiKit.fill(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := UiKit.fill(ColorRect.new()) as ColorRect
	shade.color = Color(0.02, 0.02, 0.03, 0.72)
	root.add_child(shade)
	var centre := UiKit.fill(CenterContainer.new())
	root.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	centre.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)

	body.add_child(UiKit.label("ECHOES OF BIC", 12, UiKit.FAINT))
	body.add_child(UiKit.label("Paused", 28))
	_subtitle = UiKit.label("", 14, UiKit.MUTED)
	body.add_child(_subtitle)
	body.add_child(UiKit.rule())

	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 24)
	for pair in [["WASD", "Walk"], ["Mouse", "Look"], ["E", "Use / sit at the desk"],
			["At the desk", "Drag papers and the magnifier; click the stamp, slip, radio or computer"],
			["Esc", "Stand up / pause"]]:
		var key := UiKit.label(pair[0], 13, UiKit.ACCENT)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		controls.add_child(key)
		var what := UiKit.label(pair[1], 13, UiKit.MUTED)
		what.custom_minimum_size = Vector2(280, 0)
		controls.add_child(what)
	body.add_child(controls)
	body.add_child(UiKit.rule())

	_resume = UiKit.button("Resume")
	_resume.pressed.connect(close)
	body.add_child(_resume)
	var quit := UiKit.button("Quit to title", false)
	quit.pressed.connect(func() -> void:
		close()
		quit_requested.emit())
	body.add_child(quit)

func open(subtitle: String) -> void:
	if is_open:
		return
	is_open = true
	_subtitle.text = subtitle
	visible = true
	get_tree().paused = true
	_resume.grab_focus()

## Browsers only hand the mouse back inside a click, which is why this runs from the button.
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()
