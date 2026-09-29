extends Node3D
class_name TestRoom

## Week 1-2 gray-box test scene.

@onready var player: PlayerController = $Player
@onready var hud: InteractHUD = $InteractHUD
@onready var stamp: StampAction = $Room/Desk/ApprovalStamp

var _placeholder_document: Node

func _ready() -> void:
	# README_SETUP.md section 4 — the HUD listens to the player, not the reverse.
	player.focus_changed.connect(hud._on_player_focus_changed)
	player.interacted.connect(hud._on_player_interacted)

	# Test-scene glue only: StampAction refuses to fire without a loaded document, so keep one placeholder permanently armed.
	_placeholder_document = Node.new()
	add_child(_placeholder_document)
	_placeholder_document.name = "PlaceholderForm"

	stamp.document_approved.connect(_on_document_approved)
	stamp.load_document(_placeholder_document)

func _on_document_approved(document: Node) -> void:
	# Deferred so this line lands after the player's own `interacted` feedback, and so the stamp is re-armed once this emission has finished unwinding.
	hud.show_activity.call_deferred("Stamped APPROVED — %s" % document.name)
	stamp.load_document.call_deferred(_placeholder_document)
