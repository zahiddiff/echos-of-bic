extends Control
class_name Magnifier

## The desk magnifier.

@export var zoom: float = 2.6
@export var lens_radius: float = 82.0
@export var idle_alpha: float = 0.55

signal subject_changed(subject: TextureRect)

var is_held: bool = false

var _subjects: Array[TextureRect] = []
var _active: TextureRect = null
var _grab_offset: Vector2

@onready var lens: TextureRect = $Clip/Lens
@onready var rim: Panel = $Rim
@onready var handle: Panel = $Handle

## Clip rectangles are square; the glass is round.
const ROUND_LENS := """
shader_type canvas_item;
uniform vec2 centre;
uniform float radius;
uniform vec2 rect_size;
void fragment() {
	if (distance(UV * rect_size, centre) > radius) {
		discard;
	}
}
"""

func _ready() -> void:
	var round_mask := ShaderMaterial.new()
	round_mask.shader = Shader.new()
	round_mask.shader.code = ROUND_LENS
	lens.material = round_mask
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(lens_radius * 2.0, lens_radius * 2.0)
	lens.visible = false
	modulate.a = idle_alpha

func add_subject(subject: TextureRect) -> void:
	if subject and not _subjects.has(subject):
		_subjects.append(subject)

func clear_subjects() -> void:
	_subjects.clear()
	_active = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_held = true
		_grab_offset = event.position
		move_to_front()
		modulate.a = 1.0
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_held:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_held = false
		modulate.a = idle_alpha
	elif event is InputEventMouseMotion:
		position += event.relative
		_refresh()

## The lens centre in global (viewport) coordinates.
func lens_centre() -> Vector2:
	return global_position + size * 0.5

func _refresh() -> void:
	var centre := lens_centre()
	var found: TextureRect = null
	for subject in _subjects:
		if not is_instance_valid(subject) or subject.texture == null or not subject.is_visible_in_tree():
			continue
		if Rect2(subject.global_position, subject.size).has_point(centre):
			found = subject
			break

	if found != _active:
		_active = found
		subject_changed.emit(_active)

	if _active == null:
		lens.visible = false
		return

	lens.visible = true
	lens.texture = _active.texture

	# Where the lens sits over the subject, 0..1 across the subject's rect.
	var local := (centre - _active.global_position) / _active.size
	var texture_size := Vector2(_active.texture.get_size())

	lens.size = texture_size * zoom
	# Centre the magnified image on the point currently under the lens.
	lens.position = size * 0.5 - local * lens.size
	var mask := lens.material as ShaderMaterial
	if mask:
		mask.set_shader_parameter("centre", size * 0.5 - lens.position)
		mask.set_shader_parameter("radius", minf(size.x, size.y) * 0.5 - 3.0)
		mask.set_shader_parameter("rect_size", lens.size)

	# You hold the glass above the paper, never under it.
	move_to_front()

## What the lens is currently over, or null.
func active_subject() -> TextureRect:
	return _active
