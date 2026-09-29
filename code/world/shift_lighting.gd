extends Node
class_name ShiftLighting

## Per-shift lighting: fixtures switch off and ambient fill drops as the building empties.

## Fraction of ceiling fixtures still lit, by shift.
const LIT_FRACTION := {
	1: 1.0, 2: 1.0, 3: 1.0, 4: 0.95,
	5: 0.85, 6: 0.8, 7: 0.7, 8: 0.65,
}

## Ambient fill.
const AMBIENT_ENERGY := {
	1: 0.32, 2: 0.32, 3: 0.30, 4: 0.30,
	5: 0.27, 6: 0.26, 7: 0.24, 8: 0.22,
}

@export var lights_root_path: NodePath = ^"Lights"
@export var environment_path: NodePath = ^"WorldEnvironment"

func apply(root: Node, shift: int) -> void:
	var clamped := clampi(shift, 1, ShiftSchedule.TOTAL_SHIFTS)

	var lights_root := root.get_node_or_null(lights_root_path)
	if lights_root:
		_dim_fixtures(lights_root, float(LIT_FRACTION.get(clamped, 1.0)))

	var world_env := root.get_node_or_null(environment_path) as WorldEnvironment
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.ambient_light_energy = float(AMBIENT_ENERGY.get(clamped, 0.32))
		# Very slightly colder as the building empties.
		var chill := 1.0 - (float(clamped - 1) / 14.0)
		env.ambient_light_color = Color(0.42 * chill, 0.45 * chill, 0.50)

## Turn off a deterministic share of fixtures — the same ones every time, so a shift looks the same on a replay and the player can learn the building.
func _dim_fixtures(root: Node, lit_fraction: float) -> void:
	var fixtures := _collect_lights(root)
	if fixtures.is_empty():
		return

	var keep := int(round(fixtures.size() * clampf(lit_fraction, 0.0, 1.0)))
	for i in fixtures.size():
		var on := i < keep
		fixtures[i].visible = on
		# The diffuser panel goes with its light, or you get a lit panel with no light coming off it, which reads as a bug rather than a dark room.
		var panel := root.get_node_or_null(NodePath(fixtures[i].name + "Panel"))
		if panel == null:
			panel = _find_panel(root, fixtures[i].name)
		if panel is Node3D:
			(panel as Node3D).visible = on

func _collect_lights(node: Node) -> Array[OmniLight3D]:
	var found: Array[OmniLight3D] = []
	if node is OmniLight3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_lights(child))
	return found

func _find_panel(node: Node, light_name: String) -> Node:
	var wanted := light_name + "Panel"
	if node.name == wanted:
		return node
	for child in node.get_children():
		var hit := _find_panel(child, light_name)
		if hit:
			return hit
	return null
