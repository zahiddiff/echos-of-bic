extends Node

## Gray-box generator for the whole building.
## Run: godot --headless --path <project> res://tools/build_graybox.tscn

const OUT_PATH := "res://scenes/building/bic_building.tscn"

# Local aliases so the geometry code below stays readable.
const L := preload("res://code/world/building_layout.gd")
const WALL_T := BuildingLayout.WALL_T
const CEILING_H := BuildingLayout.CEILING_H
const DOOR_H := BuildingLayout.DOOR_H
const X_MIN := BuildingLayout.X_MIN
const X_MAX := BuildingLayout.X_MAX
const Z_MIN := BuildingLayout.Z_MIN
const Z_MAX := BuildingLayout.Z_MAX
const Z_MEETING_STORAGE := BuildingLayout.Z_MEETING_STORAGE
const Z_STORAGE_MAIN := BuildingLayout.Z_STORAGE_MAIN
const Z_MAIN_PRINT := BuildingLayout.Z_MAIN_PRINT
const DOORWAY_X0 := BuildingLayout.DOORWAY_X0
const DOORWAY_X1 := BuildingLayout.DOORWAY_X1
const ENTRANCE_Z0 := BuildingLayout.ENTRANCE_Z0
const ENTRANCE_Z1 := BuildingLayout.ENTRANCE_Z1
const PLAYER_SPAWN := BuildingLayout.PLAYER_SPAWN

var _root: Node3D
var _mat: Dictionary = {}

func _ready() -> void:
	_load_materials()
	_build()
	_save()
	_root.free()
	get_tree().quit()

func _load_materials() -> void:
	for key in ["floor", "wall", "ceiling", "prop", "desk", "door", "glass", "fixture", "dark"]:
		_mat[key] = load("res://assets/materials/graybox_%s.tres" % key)

# ---------------------------------------------------------------------------
# Node helpers
# ---------------------------------------------------------------------------

func _own(node: Node) -> void:
	if node != _root:
		node.owner = _root

func _group(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	_own(node)
	return node

## Solid box with collision.
func _box(parent: Node, node_name: String, size: Vector3, pos: Vector3, mat_key: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	parent.add_child(body)
	_own(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat[mat_key]
	body.add_child(mesh_instance)
	_own(mesh_instance)

	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	_own(collider)

	return body

## Visual-only box (no collision) — light fixtures, signage, trim.
func _decal(parent: Node, node_name: String, size: Vector3, pos: Vector3, mat_key: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat[mat_key]
	parent.add_child(mesh_instance)
	_own(mesh_instance)
	return mesh_instance

## A wall running along X at a fixed Z, broken by doorway openings.
func _wall_along_x(parent: Node, node_name: String, z: float, x0: float, x1: float, openings: Array, mat_key: String) -> void:
	var edges: Array[float] = [x0]
	for opening: Vector2 in openings:
		edges.append(opening.x)
		edges.append(opening.y)
	edges.append(x1)

	var index := 0
	while index < edges.size() - 1:
		var seg_start: float = edges[index]
		var seg_end: float = edges[index + 1]
		var is_solid := index % 2 == 0
		var length := seg_end - seg_start
		if length > 0.001:
			if is_solid:
				_box(parent, "%s_Seg%d" % [node_name, index], Vector3(length, CEILING_H, WALL_T),
					Vector3((seg_start + seg_end) * 0.5, CEILING_H * 0.5, z), mat_key)
			else:
				# Header above the doorway.
				var header_h := CEILING_H - DOOR_H
				_box(parent, "%s_Header%d" % [node_name, index], Vector3(length, header_h, WALL_T),
					Vector3((seg_start + seg_end) * 0.5, DOOR_H + header_h * 0.5, z), mat_key)
		index += 1

## A wall running along Z at a fixed X, broken by openings (Vector2(z_start, z_end)).
func _wall_along_z(parent: Node, node_name: String, x: float, z0: float, z1: float, openings: Array, mat_key: String) -> void:
	var edges: Array[float] = [z0]
	for opening: Vector2 in openings:
		edges.append(opening.x)
		edges.append(opening.y)
	edges.append(z1)

	var index := 0
	while index < edges.size() - 1:
		var seg_start: float = edges[index]
		var seg_end: float = edges[index + 1]
		var is_solid := index % 2 == 0
		var length := seg_end - seg_start
		if length > 0.001:
			if is_solid:
				_box(parent, "%s_Seg%d" % [node_name, index], Vector3(WALL_T, CEILING_H, length),
					Vector3(x, CEILING_H * 0.5, (seg_start + seg_end) * 0.5), mat_key)
			else:
				var header_h := CEILING_H - DOOR_H
				_box(parent, "%s_Header%d" % [node_name, index], Vector3(WALL_T, header_h, length),
					Vector3(x, DOOR_H + header_h * 0.5, (seg_start + seg_end) * 0.5), mat_key)
		index += 1

func _fixture(parent: Node, node_name: String, x: float, z: float) -> void:
	_decal(parent, node_name + "Panel", Vector3(1.3, 0.06, 0.3), Vector3(x, CEILING_H - 0.04, z), "fixture")
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = Vector3(x, CEILING_H - 0.25, z)
	light.light_color = Color(0.9, 0.94, 1.0)
	light.light_energy = 1.05
	light.omni_range = 7.0
	light.shadow_enabled = false
	parent.add_child(light)
	_own(light)

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build() -> void:
	_root = Node3D.new()
	_root.name = "BICBuilding"
	_root.set_script(load("res://code/world/bic_building.gd"))

	_build_environment()
	var shell := _group(_root, "Shell")
	_build_shell(shell)
	var partitions := _group(_root, "Partitions")
	_build_partitions(partitions)
	var doors := _group(_root, "Doors")
	_build_doors(doors)
	var props := _group(_root, "Props")
	_build_props(props)
	var lights := _group(_root, "Lights")
	_build_lights(lights)
	_build_actors()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.5)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	_root.add_child(world_env)
	_own(world_env)

func _build_shell(parent: Node) -> void:
	var width := X_MAX - X_MIN
	var depth := Z_MAX - Z_MIN
	var mid_z := (Z_MIN + Z_MAX) * 0.5

	_box(parent, "Floor", Vector3(width + WALL_T * 2.0, WALL_T, depth + WALL_T * 2.0),
		Vector3(0, -WALL_T * 0.5, mid_z), "floor")
	_box(parent, "Ceiling", Vector3(width + WALL_T * 2.0, WALL_T, depth + WALL_T * 2.0),
		Vector3(0, CEILING_H + WALL_T * 0.5, mid_z), "ceiling")

	_wall_along_x(parent, "WallNorth", Z_MIN - WALL_T * 0.5, X_MIN, X_MAX, [], "wall")
	_wall_along_x(parent, "WallSouth", Z_MAX + WALL_T * 0.5, X_MIN, X_MAX, [], "wall")
	_wall_along_z(parent, "WallWest", X_MIN - WALL_T * 0.5, Z_MIN, Z_MAX, [], "wall")
	_wall_along_z(parent, "WallEast", X_MAX + WALL_T * 0.5, Z_MIN, Z_MAX,
		[Vector2(ENTRANCE_Z0, ENTRANCE_Z1)], "wall")

	# A strip of pavement outside, so arriving visitors are walking on something while they are visible through the glass.
	var e := L.entrance_centre()
	_box(parent, "Pavement", Vector3(4.0, WALL_T, 4.0),
		Vector3(X_MAX + WALL_T + 2.0, -WALL_T * 0.5, e.z), "floor")

func _build_partitions(parent: Node) -> void:
	var opening := [Vector2(DOORWAY_X0, DOORWAY_X1)]
	_wall_along_x(parent, "PartitionMeeting", Z_MEETING_STORAGE, X_MIN, X_MAX, opening, "wall")
	_wall_along_x(parent, "PartitionStorage", Z_STORAGE_MAIN, X_MIN, X_MAX, opening, "wall")
	_wall_along_x(parent, "PartitionPrint", Z_MAIN_PRINT, X_MIN, X_MAX, opening, "wall")

func _build_doors(parent: Node) -> void:
	# Unlocked: the print room is a required destination for physical tasks.
	_hinged_door(parent, "DoorPrintRoom", Z_MAIN_PRINT, -90.0, false,
		"Open the print room door")
	# Locked by default per the design — staff don't have free run of the building.
	_hinged_door(parent, "DoorStorage", Z_STORAGE_MAIN, 90.0, true, "Open the storage door")
	_hinged_door(parent, "DoorMeetingRoom", Z_MEETING_STORAGE, 90.0, true, "Open the meeting room door")
	_sliding_entrance(parent)

func _hinged_door(parent: Node, node_name: String, z: float, open_angle: float, is_locked: bool, prompt: String) -> void:
	var leaf_width := DOORWAY_X1 - DOORWAY_X0

	var door := StaticBody3D.new()
	door.name = node_name
	door.set_script(load("res://code/world/door.gd"))
	door.position = Vector3(DOORWAY_X0, 0, z)
	parent.add_child(door)
	_own(door)

	door.set("prompt_text", prompt)
	door.set("open_prompt", prompt)
	door.set("close_prompt", prompt.replace("Open", "Close"))
	door.set("locked", is_locked)
	door.set("locked_prompt_text", "Locked")
	door.set("open_angle_degrees", open_angle)

	var leaf_centre := Vector3(leaf_width * 0.5, DOOR_H * 0.5, 0)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Leaf"
	mesh_instance.position = leaf_centre
	var mesh := BoxMesh.new()
	mesh.size = Vector3(leaf_width, DOOR_H, 0.06)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat["door"]
	door.add_child(mesh_instance)
	_own(mesh_instance)

	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.position = leaf_centre
	var shape := BoxShape3D.new()
	shape.size = Vector3(leaf_width, DOOR_H, 0.06)
	collider.shape = shape
	door.add_child(collider)
	_own(collider)

	# Handle, so which edge swings is readable in gray-box.
	_decal(door, "Handle", Vector3(0.1, 0.04, 0.16),
		Vector3(leaf_width - 0.16, 1.05, 0), "dark")

func _sliding_entrance(parent: Node) -> void:
	var opening_width := ENTRANCE_Z1 - ENTRANCE_Z0
	var leaf_width := opening_width * 0.5
	var centre_z := (ENTRANCE_Z0 + ENTRANCE_Z1) * 0.5

	var entrance := Node3D.new()
	entrance.name = "Entrance"
	entrance.set_script(load("res://code/world/sliding_entrance.gd"))
	entrance.position = Vector3(X_MAX + WALL_T * 0.5, 0, centre_z)
	parent.add_child(entrance)
	_own(entrance)
	entrance.set("slide_distance", leaf_width)

	_entrance_leaf(entrance, "LeftPanel", -leaf_width * 0.5, leaf_width)
	_entrance_leaf(entrance, "RightPanel", leaf_width * 0.5, leaf_width)

	var trigger := Area3D.new()
	trigger.name = "Trigger"
	# Straddles the doorway so people approaching from outside open it too.
	trigger.position = Vector3(0.0, 1.0, 0)
	# Actors only (layer 2).
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.monitorable = false
	parent_add_owned(entrance, trigger)
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	# Narrow along the wall, so someone standing at the counter never holds the doors open.
	box.size = Vector3(3.2, 2.0, opening_width + 0.4)
	trigger_shape.shape = box
	parent_add_owned(trigger, trigger_shape)

	var audio := AudioStreamPlayer3D.new()
	audio.name = "AudioStreamPlayer3D"
	parent_add_owned(entrance, audio)

	var timer := Timer.new()
	timer.name = "CloseTimer"
	timer.one_shot = true
	timer.wait_time = 1.4
	parent_add_owned(entrance, timer)

func _entrance_leaf(parent: Node, node_name: String, local_z: float, leaf_width: float) -> void:
	var leaf := StaticBody3D.new()
	leaf.name = node_name
	leaf.position = Vector3(0, 0, local_z)
	parent_add_owned(parent, leaf)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Glass"
	mesh_instance.position = Vector3(0, DOOR_H * 0.5, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, DOOR_H, leaf_width)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _mat["glass"]
	parent_add_owned(leaf, mesh_instance)

	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.position = Vector3(0, DOOR_H * 0.5, 0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.08, DOOR_H, leaf_width)
	collider.shape = shape
	parent_add_owned(leaf, collider)

func parent_add_owned(parent: Node, child: Node) -> void:
	parent.add_child(child)
	_own(child)

func _build_props(parent: Node) -> void:
	_build_player_desk(_group(parent, "PlayerDesk"))
	_build_other_desk(_group(parent, "OtherDesk"))
	_build_print_room(_group(parent, "PrintRoom"))
	_build_storage(_group(parent, "Storage"))
	_build_meeting_room(_group(parent, "MeetingRoom"))
	_build_story_props(_group(parent, "Story"))

func _build_player_desk(parent: Node) -> void:
	# Counter runs east-west.
	var counter_len := L.COUNTER_X1 - L.COUNTER_X0
	_box(parent, "Counter", Vector3(counter_len, L.COUNTER_H, L.COUNTER_DEPTH),
		L.counter_centre(), "desk")
	_player_station(parent)
	_desk_actions(parent)
	# A short return at the west end makes it a proper service counter.
	var back := L.counter_back_z()
	_box(parent, "CounterReturn", Vector3(0.6, L.COUNTER_H, 0.9),
		Vector3(L.COUNTER_X0 + 0.3, L.COUNTER_H * 0.5, back + 0.45), "desk")
	_decal(parent, "MonitorStand", Vector3(0.16, 0.12, 0.14),
		Vector3(L.COUNTER_X0 + 0.35, L.COUNTER_H + 0.06, L.COUNTER_Z + 0.15), "dark")
	# Kept clear of the spawn point and of the lane to the print room door.
	_box(parent, "Chair", Vector3(0.45, 0.45, 0.45),
		Vector3(X_MAX - 0.5, 0.225, L.SEAT.z), "prop")
	_decal(parent, "ChairBack", Vector3(0.45, 0.5, 0.08),
		Vector3(X_MAX - 0.5, 0.7, L.SEAT.z + 0.2), "prop")
	_box(parent, "Bin", Vector3(0.3, 0.4, 0.3),
		Vector3(X_MAX - 0.35, 0.2, L.COUNTER_Z), "dark")

## Approve / Reject / Flag as physical objects on the counter, each clickable while seated (ClickTarget) and usable by E while standing.
func _desk_actions(parent: Node) -> void:
	# Laid out along the player's side of the counter, left to right: terminal, rejection slips, stamp, [papers tray], radio.
	var top := L.COUNTER_H
	var near_z := L.COUNTER_Z + 0.15

	_desk_action(parent, "RecordsComputer",
		"res://code/desk/records_computer.gd", "Use the records terminal",
		Vector3(L.COUNTER_X0 + 0.35, top, near_z), Vector3(0.5, 0.33, 0.05))

	_desk_action(parent, "RejectionSlip",
		"res://code/desk/rejection_slip.gd", "Fill out a rejection slip",
		Vector3(L.COUNTER_X0 + 0.9, top, near_z), Vector3(0.24, 0.03, 0.18))

	var stamp := _desk_action(parent, "ApprovalStamp",
		"res://code/examples/stamp_action.gd", "Stamp APPROVED",
		Vector3(L.COUNTER_X0 + 1.25, top, near_z), Vector3(0.13, 0.17, 0.13))
	_decal(stamp, "Handle", Vector3(0.07, 0.06, 0.07), Vector3(0, 0.20, 0), "dark")

	var radio := _desk_action(parent, "DeskRadio",
		"res://code/desk/desk_radio.gd", "Call security on the radio",
		Vector3(L.COUNTER_X1 - 0.2, top, near_z), Vector3(0.12, 0.22, 0.10))
	_decal(radio, "Aerial", Vector3(0.012, 0.22, 0.012), Vector3(0.04, 0.22, 0), "dark")

	var timer := Timer.new()
	timer.name = "CallTimer"
	timer.one_shot = true
	timer.wait_time = 16.0
	radio.add_child(timer)
	_own(timer)

## One desk action: mesh, collision sized to the mesh, audio player and the ClickTarget that makes it usable with a mouse while seated.
func _desk_action(parent: Node, node_name: String, script_path: String, prompt: String,
		position: Vector3, box: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.set_script(load(script_path))
	body.position = position
	parent.add_child(body)
	_own(body)
	body.set("prompt_text", prompt)

	_decal(body, "Mesh", box, Vector3(0, box.y * 0.5, 0), "prop")

	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	# Padded so small props are still easy to look at and to click.
	shape.size = Vector3(maxf(box.x, 0.16), maxf(box.y, 0.14), maxf(box.z, 0.16))
	collider.shape = shape
	collider.position = Vector3(0, shape.size.y * 0.5, 0)
	body.add_child(collider)
	_own(collider)

	var audio := AudioStreamPlayer3D.new()
	audio.name = "AudioStreamPlayer3D"
	body.add_child(audio)
	_own(audio)

	var click := Node.new()
	click.name = "ClickTarget"
	click.set_script(load("res://code/desk/click_target.gd"))
	body.add_child(click)
	_own(click)

	return body

## The station itself: an Interactable on the counter plus the marker that defines the fixed seated view.
func _player_station(parent: Node) -> void:
	var station := StaticBody3D.new()
	station.name = "DeskStation"
	station.set_script(load("res://code/desk/desk_station.gd"))
	station.position = L.DESK_STATION
	parent.add_child(station)
	_own(station)
	station.set("stand_prompt", "Work the desk")
	station.set("prompt_text", "Work the desk")

	# The tray of papers you press E on.
	var tray := MeshInstance3D.new()
	tray.name = "Tray"
	var tray_mesh := BoxMesh.new()
	tray_mesh.size = Vector3(0.34, 0.03, 0.26)
	tray.mesh = tray_mesh
	tray.material_override = _mat["prop"]
	tray.position = Vector3(0, 0.02, 0)
	station.add_child(tray)
	_own(tray)

	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	# Generous enough that glancing at the papers focuses them.
	shape.size = Vector3(0.44, 0.26, 0.36)
	collider.shape = shape
	collider.position = Vector3(0, 0.10, 0)
	station.add_child(collider)
	_own(collider)

	# Seated view: behind the counter, looking across it and slightly down.
	var seat := Marker3D.new()
	seat.name = "SeatMarker"
	seat.position = L.SEAT - L.DESK_STATION
	seat.rotation = Vector3(deg_to_rad(L.SEAT_PITCH_DEGREES), 0.0, 0.0)
	station.add_child(seat)
	_own(seat)

func _build_other_desk(parent: Node) -> void:
	# Rahat's station, across the main floor to the west.
	var d := L.RAHAT_DESK
	_box(parent, "Desk", Vector3(1.6, 0.75, 0.8), Vector3(d.x, 0.375, d.z), "desk")
	_decal(parent, "Monitor", Vector3(0.52, 0.34, 0.04), Vector3(d.x, 0.94, d.z - 0.25), "dark")
	_decal(parent, "MonitorStand", Vector3(0.16, 0.12, 0.14), Vector3(d.x, 0.81, d.z - 0.25), "dark")
	_box(parent, "Chair", Vector3(0.45, 0.45, 0.45), Vector3(d.x, 0.225, d.z + 0.8), "prop")
	_decal(parent, "ChairBack", Vector3(0.45, 0.5, 0.08), Vector3(d.x, 0.7, d.z + 1.0), "prop")
	_box(parent, "Cabinet", Vector3(0.5, 1.3, 1.0), Vector3(X_MIN + 0.3, 0.65, d.z - 1.2), "prop")

	# Rahat's things, in their own node.
	var his := _group(parent, "RahatThings")
	_decal(his, "Mug", Vector3(0.08, 0.10, 0.08), Vector3(d.x + 0.6, 0.80, d.z + 0.15), "prop")
	_decal(his, "Folder", Vector3(0.24, 0.02, 0.32), Vector3(d.x - 0.5, 0.76, d.z + 0.1), "dark")
	_decal(his, "Jacket", Vector3(0.40, 0.55, 0.10), Vector3(d.x, 0.75, d.z + 1.07), "dark")

	# Rahat himself, in his chair, facing his monitor.
	var him := AnimatableBody3D.new()
	him.name = "Rahat"
	him.set_script(load("res://code/world/visitor_figure.gd"))
	him.position = Vector3(d.x, 0.0, d.z + 0.8)
	his.add_child(him)
	_own(him)
	him.set("skin", Color(0.55, 0.40, 0.30))
	him.set("hair", Color(0.07, 0.06, 0.06))
	him.set("jacket", Color(0.17, 0.21, 0.30))
	him.set("trousers", Color(0.20, 0.20, 0.22))
	him.set("pose", 1)
	him.set("facial_hair", 1)

func _build_print_room(parent: Node) -> void:
	_box(parent, "Printer", Vector3(0.9, 1.15, 0.7), Vector3(-3.0, 0.575, Z_MAX - 0.7), "prop")
	_box(parent, "WorkCounter", Vector3(3.0, 0.9, 0.6), Vector3(1.4, 0.45, Z_MAX - 0.3), "desk")
	_box(parent, "Shelving", Vector3(0.5, 1.9, 1.4), Vector3(X_MIN + 0.25, 0.95, Z_MAIN_PRINT + 0.9), "prop")
	_box(parent, "Crate", Vector3(0.6, 0.6, 0.6), Vector3(-1.0, 0.3, Z_MAIN_PRINT + 1.0), "prop")

func _build_storage(parent: Node) -> void:
	# Open, sparsely used — a couple of racks and not much else.
	var mid := (Z_MEETING_STORAGE + Z_STORAGE_MAIN) * 0.5
	_box(parent, "Rack1", Vector3(0.6, 2.0, 1.0), Vector3(X_MIN + 0.3, 1.0, mid - 0.7), "prop")
	_box(parent, "Rack2", Vector3(0.6, 2.0, 1.0), Vector3(X_MIN + 0.3, 1.0, mid + 0.5), "prop")
	_box(parent, "Crate1", Vector3(0.8, 0.8, 0.8), Vector3(-2.2, 0.4, mid - 0.6), "prop")
	_box(parent, "Crate2", Vector3(0.6, 0.6, 0.6), Vector3(-1.4, 0.3, mid + 0.8), "prop")
	_box(parent, "Crate3", Vector3(0.7, 0.7, 0.7), Vector3(1.2, 0.35, mid - 0.8), "prop")

func _build_meeting_room(parent: Node) -> void:
	var mid := (Z_MIN + Z_MEETING_STORAGE) * 0.5
	_box(parent, "Table", Vector3(3.6, 0.75, 1.2), Vector3(-0.6, 0.375, mid), "desk")
	var chair_x := [-1.8, -0.6, 0.6]
	for index in chair_x.size():
		_box(parent, "ChairN%d" % (index + 1), Vector3(0.45, 0.45, 0.45),
			Vector3(chair_x[index], 0.225, mid - 0.95), "prop")
		_box(parent, "ChairS%d" % (index + 1), Vector3(0.45, 0.45, 0.45),
			Vector3(chair_x[index], 0.225, mid + 0.95), "prop")
	_box(parent, "Sideboard", Vector3(2.0, 0.85, 0.5), Vector3(-3.2, 0.425, Z_MIN + 0.3), "prop")

## Environmental storytelling.
func _build_story_props(parent: Node) -> void:
	# Goes up on the wall just inside the entrance after a stalker gets past the desk.
	var flyer := _decal(parent, "MissingPersonFlyer", Vector3(0.21, 0.30, 0.004),
		Vector3(X_MAX - 0.02, 1.55, ENTRANCE_Z1 + 0.6), "prop")
	flyer.rotation = Vector3(0, deg_to_rad(-90.0), 0)
	flyer.visible = false

	# A memo, left on the counter, in flat bureaucratic language.
	var memo := _decal(parent, "SecurityMemo", Vector3(0.21, 0.004, 0.30),
		Vector3(L.COUNTER_X0 + 0.95, L.COUNTER_H + 0.005, L.counter_front_z() + 0.18), "prop")
	memo.visible = false

	# Pinned to the board on Rahat's desk.
	var d := L.RAHAT_DESK
	var clipping := _decal(parent, "NewsClipping", Vector3(0.16, 0.22, 0.004),
		Vector3(d.x + 0.3, 1.5, d.z - 0.40), "prop")
	clipping.visible = false

	# The board it goes on is always there; the clipping is not.
	_decal(parent, "Bulletin", Vector3(1.1, 0.7, 0.03), Vector3(d.x, 1.5, d.z - 0.42), "dark")

func _build_lights(parent: Node) -> void:
	var main_floor := _group(parent, "MainFloor")
	for x in [-2.6, 0.0, 2.6]:
		_fixture(main_floor, "Light_Main_%d_A" % int(x * 10), x, Z_STORAGE_MAIN + 1.5)
		_fixture(main_floor, "Light_Main_%d_B" % int(x * 10), x, Z_MAIN_PRINT - 1.4)

	var print_room := _group(parent, "PrintRoom")
	var print_mid := (Z_MAIN_PRINT + Z_MAX) * 0.5
	_fixture(print_room, "Light_Print_A", -2.0, print_mid)
	_fixture(print_room, "Light_Print_B", 2.0, print_mid)

	var storage := _group(parent, "Storage")
	var storage_mid := (Z_MEETING_STORAGE + Z_STORAGE_MAIN) * 0.5
	_fixture(storage, "Light_Storage_A", -2.0, storage_mid)
	_fixture(storage, "Light_Storage_B", 1.6, storage_mid)

	var meeting := _group(parent, "MeetingRoom")
	var meeting_mid := (Z_MIN + Z_MEETING_STORAGE) * 0.5
	_fixture(meeting, "Light_Meeting_A", -2.0, meeting_mid)
	_fixture(meeting, "Light_Meeting_B", 1.6, meeting_mid)

func _build_actors() -> void:
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = PLAYER_SPAWN
	_root.add_child(player)
	_own(player)

	var hud: Node = load("res://scenes/ui/interact_hud.tscn").instantiate()
	hud.name = "InteractHUD"
	_root.add_child(hud)
	_own(hud)

	var viewer: Node = load("res://scenes/desk/document_viewer.tscn").instantiate()
	viewer.name = "DocumentViewer"
	viewer.visible = false
	_root.add_child(viewer)
	_own(viewer)

	var terminal: Node = load("res://scenes/desk/terminal_screen.tscn").instantiate()
	terminal.name = "TerminalScreen"
	terminal.visible = false
	_root.add_child(terminal)
	_own(terminal)

	var dialogue: Node = load("res://scenes/desk/dialogue_view.tscn").instantiate()
	dialogue.name = "DialogueView"
	dialogue.visible = false
	_root.add_child(dialogue)
	_own(dialogue)

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func _save() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var packed := PackedScene.new()
	var pack_result := packed.pack(_root)
	if pack_result != OK:
		push_error("pack() failed: %d" % pack_result)
		print("FAILED to pack scene: %d" % pack_result)
		return
	var save_result := ResourceSaver.save(packed, OUT_PATH)
	if save_result != OK:
		push_error("save() failed: %d" % save_result)
		print("FAILED to save scene: %d" % save_result)
		return
	print("wrote %s  (%d nodes)" % [OUT_PATH, _count(_root)])

func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total
