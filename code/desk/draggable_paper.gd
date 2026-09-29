extends PanelContainer
class_name DraggablePaper

## A sheet of paper on the desk.

signal picked_up(paper: DraggablePaper)
signal dropped(paper: DraggablePaper)

@export var drag_enabled: bool = true
## Degrees of tilt applied while held, so papers feel handled rather than snapped.
@export var lift_tilt: float = 1.5

var is_held: bool = false

var _grab_offset: Vector2
var _rest_rotation: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	_rest_rotation = rotation_degrees
	resized.connect(func() -> void: pivot_offset = size * 0.5)

func _gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		elif is_held:
			_end_drag()
		accept_event()

	elif event is InputEventMouseMotion and is_held:
		# Positions are parent-space; event.position is local to this control.
		position += event.position - _grab_offset
		_clamp_into_parent()
		accept_event()

func _begin_drag(local_position: Vector2) -> void:
	is_held = true
	_grab_offset = local_position
	move_to_front()
	rotation_degrees = _rest_rotation + lift_tilt
	picked_up.emit(self)

func _end_drag() -> void:
	is_held = false
	rotation_degrees = _rest_rotation
	dropped.emit(self)

func _input(event: InputEvent) -> void:
	# Releasing the button off the edge of the paper still has to drop it.
	if not is_held:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()

func _clamp_into_parent() -> void:
	var parent := get_parent_control()
	if parent == null:
		return
	var limit := parent.size - size
	position.x = clampf(position.x, -size.x * 0.4, maxf(limit.x + size.x * 0.4, 0.0))
	position.y = clampf(position.y, -size.y * 0.25, maxf(limit.y + size.y * 0.25, 0.0))

## Put the paper back where it started, e.g. when a visitor is finished.
func reset_to(target: Vector2) -> void:
	is_held = false
	position = target
	rotation_degrees = _rest_rotation
