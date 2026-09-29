extends CanvasLayer
class_name InteractHUD

## Crosshair and interact prompt, driven by PlayerController's focus_changed / interacted.

@export var activity_line_seconds: float = 1.6

@onready var prompt_label: Label = $PromptLabel
@onready var activity_label: Label = $ActivityLabel
@onready var activity_timer: Timer = $ActivityTimer

func _ready() -> void:
	prompt_label.visible = false
	activity_label.visible = false
	activity_timer.wait_time = activity_line_seconds
	activity_timer.timeout.connect(_on_activity_timeout)

## Connect PlayerController.focus_changed here.
func _on_player_focus_changed(interactable: Node) -> void:
	if interactable:
		prompt_label.text = interactable.get_prompt()
		prompt_label.visible = true
	else:
		prompt_label.visible = false

## Connect PlayerController.interacted here.
func _on_player_interacted(interactable: Node) -> void:
	if interactable == null:
		return
	if interactable.get("locked"):
		show_activity("%s — locked" % interactable.name)
	else:
		show_activity("Used: %s" % interactable.name)
	# Prompt text often changes as a result of interacting (e.g. lamp on/off), so refresh it without waiting for focus to change.
	prompt_label.text = interactable.get_prompt()

func show_activity(text: String) -> void:
	activity_label.text = text
	activity_label.visible = true
	activity_timer.start()

func _on_activity_timeout() -> void:
	activity_label.visible = false
