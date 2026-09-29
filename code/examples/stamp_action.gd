extends Interactable
class_name StampAction

## Example Interactable: the approval stamp on the desk.
## This is the pattern to copy for the rejection slip and the radio (Flag).

signal document_approved(document: Node)

@export var stamp_sound: AudioStream
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var current_document: Node = null

func interact(player: Node) -> void:
	if locked or current_document == null:
		return

	if stamp_sound:
		audio_player.stream = stamp_sound
		audio_player.play()

	document_approved.emit(current_document)
	current_document = null

	super.interact(player)

func load_document(document: Node) -> void:
	current_document = document
