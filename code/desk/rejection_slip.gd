extends Interactable
class_name RejectionSlip

## The rejection slip pad on the desk.

signal document_rejected(document: Node)

@export var slip_sound: AudioStream
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var current_document: Node = null

func interact(player: Node) -> void:
	if locked or current_document == null:
		return

	if slip_sound:
		audio_player.stream = slip_sound
		audio_player.play()

	document_rejected.emit(current_document)
	current_document = null

	super.interact(player)

func load_document(document: Node) -> void:
	current_document = document
