extends Control

## New Game name entry.

@export_file("*.tscn") var next_scene: String = "res://scenes/building/bic_building.tscn"
@export var max_name_length: int = 24

@onready var name_field: LineEdit = $Frame/Panel/Form/NameField
@onready var begin_button: Button = $Frame/Panel/Form/BeginButton
@onready var error_label: Label = $Frame/Panel/Form/ErrorLabel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	error_label.visible = false
	name_field.max_length = max_name_length
	name_field.text = GameState.player_name
	name_field.grab_focus()

	name_field.text_submitted.connect(_on_text_submitted)
	name_field.text_changed.connect(_on_text_changed)
	begin_button.pressed.connect(_submit)

func _on_text_submitted(_text: String) -> void:
	_submit()

func _on_text_changed(_text: String) -> void:
	error_label.visible = false

func _submit() -> void:
	var entered := name_field.text.strip_edges()
	if entered.is_empty():
		error_label.text = "Enter a name to continue."
		error_label.visible = true
		name_field.grab_focus()
		return

	GameState.set_player_name(entered)
	get_tree().change_scene_to_file(next_scene)
