extends Interactable
class_name TestLamp

## Gray-box test object: a desk lamp the player can switch on and off.

@export var on_prompt: String = "Turn off the lamp"
@export var off_prompt: String = "Turn on the lamp"
@export var starts_on: bool = false

@onready var light: OmniLight3D = $OmniLight3D
@onready var bulb: MeshInstance3D = $Bulb

var is_on: bool = false

signal toggled(now_on: bool)

var _bulb_material: StandardMaterial3D

func _ready() -> void:
	var base := bulb.get_active_material(0)
	if base is StandardMaterial3D:
		_bulb_material = base.duplicate()
		bulb.set_surface_override_material(0, _bulb_material)
	_set_state(starts_on)

func interact(player: Node) -> void:
	if locked:
		return

	_set_state(not is_on)
	toggled.emit(is_on)

	super.interact(player)

func _set_state(value: bool) -> void:
	is_on = value
	light.visible = is_on
	prompt_text = on_prompt if is_on else off_prompt
	if _bulb_material:
		_bulb_material.emission_enabled = is_on
