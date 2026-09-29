extends CanvasLayer
class_name StatusBar

## Shift, clock, queue and strikes, top-left.

var _shift_label: Label
var _clock_label: Label
var _queue_label: Label
var _pips: Array[ColorRect] = []

func _ready() -> void:
	layer = 4
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiKit.panel_style(Color(0.05, 0.055, 0.065, 0.72), 12, Color(1, 1, 1, 0.08))
	style.shadow_size = 0
	style.content_margin_left = 14
	style.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	_clock_label = UiKit.label("21:00", 22, UiKit.INK)
	_clock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_clock_label)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	_shift_label = UiKit.label("SHIFT 1", 12, UiKit.ACCENT)
	_shift_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_shift_label)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	column.add_child(line)
	_queue_label = UiKit.label("", 12, UiKit.MUTED)
	_queue_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(_queue_label)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	line.add_child(pips)
	for i in GameState.MAX_STRIKES:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 5)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
		_pips.append(pip)
	set_strikes(GameState.strikes_remaining())

func set_shift(shift: int, training: bool, demo: bool = false) -> void:
	var total := GameState.DEMO_LAST_SHIFT if demo else ShiftSchedule.TOTAL_SHIFTS
	_shift_label.text = "SHIFT %d  ·  TRAINING" % shift if training else "SHIFT %d OF %d" % [shift, total]
	if demo:
		_shift_label.text += "  ·  DEMO"

var _lockdown := false

func set_lockdown(on: bool) -> void:
	_lockdown = on
	if on:
		_shift_label.text = "LOCKDOWN"
		_shift_label.add_theme_color_override("font_color", UiKit.DANGER)
		_queue_label.text = "Doors locked"

func set_clock(text: String) -> void:
	_clock_label.text = text

func set_waiting(count: int) -> void:
	if _lockdown:
		return
	if count <= 0:
		_queue_label.text = "Queue empty"
	else:
		_queue_label.text = "%d in queue" % count

func set_strikes(left: int) -> void:
	for i in _pips.size():
		_pips[i].color = UiKit.ACCENT if i < left else Color(0.25, 0.25, 0.27)
