extends StaticBody3D
class_name Interactable

## Echoes of BIC — Base Interactable
## Extend this for anything the player can look at and press Interact on:
## the stamp, the rejection slip, the radio, doors, documents in the tray,
## the printer, etc. Attach a CollisionShape3D as a child so the player's
## InteractRay can hit it directly.

@export var prompt_text: String = "Interact"
@export var locked: bool = false
@export var locked_prompt_text: String = "Locked"

signal used(player: Node)

func get_interactable() -> Node:
	return self

func get_prompt() -> String:
	return locked_prompt_text if locked else prompt_text

## Override this in subclasses (stamp, radio, door, printer, etc).
## Always call `super.interact(player)` last if you override, so `used` still fires.
func interact(player: Node) -> void:
	if locked:
		return
	used.emit(player)
