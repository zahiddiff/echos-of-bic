extends RefCounted
class_name UiKit

## Shared look for the screens built in code.

const INK := Color(0.93, 0.92, 0.88)
const MUTED := Color(0.60, 0.62, 0.65)
const FAINT := Color(0.40, 0.41, 0.44)
const PANEL := Color(0.075, 0.08, 0.095, 0.97)
const EDGE := Color(0.24, 0.25, 0.28)
const ACCENT := Color(0.86, 0.74, 0.47)
const DANGER := Color(0.84, 0.43, 0.38)

static func panel_style(bg: Color = PANEL, margin: float = 32.0, edge: Color = EDGE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 18
	return box

static func label(text: String, size: int = 16, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func rule(color: Color = EDGE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	return r

static func button(text: String, primary: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_ALL
	var fill := ACCENT if primary else Color(0.16, 0.17, 0.19)
	var text_colour := Color(0.08, 0.08, 0.09) if primary else INK
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		if state == "hover" or state == "focus":
			box.bg_color = fill.lightened(0.12)
		elif state == "pressed":
			box.bg_color = fill.darkened(0.15)
		box.set_corner_radius_all(2)
		box.set_content_margin_all(10)
		if not primary:
			box.border_color = EDGE
			box.set_border_width_all(1)
		b.add_theme_stylebox_override(state, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, text_colour)
	return b

## A full-screen control that ignores the mouse unless told otherwise.
static func fill(control: Control) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control
