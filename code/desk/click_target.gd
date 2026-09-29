extends Node
class_name ClickTarget

## Makes the Interactable it is parented to clickable.

signal clicked(target: Node)
signal hovered(target: Node, inside: bool)

@export var enabled: bool = true

var _body: CollisionObject3D

func _ready() -> void:
	_body = get_parent() as CollisionObject3D
	if _body == null:
		push_warning("ClickTarget must be a child of a CollisionObject3D; got %s" % get_parent())
		return
	_body.input_ray_pickable = true
	_body.input_event.connect(_on_body_input_event)
	_body.mouse_entered.connect(_set_hover.bind(true))
	_body.mouse_exited.connect(_set_hover.bind(false))

static var _glow: StandardMaterial3D

## A faint lift in brightness while the pointer is over the object.
func _set_hover(inside: bool) -> void:
	if not enabled:
		inside = false
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow.albedo_color = Color(1.0, 0.9, 0.7, 0.16)
	for mesh in _body.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = _glow if inside else null
	hovered.emit(_body, inside)

func _on_body_input_event(_camera: Node, event: InputEvent, _position: Vector3,
		_normal: Vector3, _shape_index: int) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(_body)
