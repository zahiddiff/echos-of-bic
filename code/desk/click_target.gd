extends Node
class_name ClickTarget

## Makes the Interactable it is parented to clickable.

signal clicked(target: Node)

@export var enabled: bool = true

var _body: CollisionObject3D

func _ready() -> void:
	_body = get_parent() as CollisionObject3D
	if _body == null:
		push_warning("ClickTarget must be a child of a CollisionObject3D; got %s" % get_parent())
		return
	_body.input_ray_pickable = true
	_body.input_event.connect(_on_body_input_event)

func _on_body_input_event(_camera: Node, event: InputEvent, _position: Vector3,
		_normal: Vector3, _shape_index: int) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(_body)
