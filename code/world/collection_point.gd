extends Interactable
class_name CollectionPoint

## Where physical tasks are fetched from: the printer for printouts, the shelf for parcels.

signal collected(request: VisitorRequest)

## "printout" or "parcel", matching TaskPool.COLLECTION.
@export var kind: String = "printout"
@export var idle_prompt: String = "Nothing waiting"
@export var pickup_sound: AudioStream

## Whatever the desk is currently waiting on, if it comes from here.
var pending: VisitorRequest

var _marker: MeshInstance3D
var _audio: AudioStreamPlayer3D

func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)

## Size the reachable box and the "something is waiting" marker.
func setup(box_size: Vector3, marker_offset: Vector3, marker_size: Vector3, marker_colour: Color) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	add_child(shape)
	_marker = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = marker_size
	_marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = marker_colour
	_marker.material_override = mat
	_marker.position = marker_offset
	_marker.visible = false
	add_child(_marker)

func wait_for(request: VisitorRequest) -> void:
	pending = request if request and TaskPool.collection_kind(request.task_id) == kind and not request.collected else null
	if _marker:
		_marker.visible = pending != null

func get_prompt() -> String:
	if pending == null:
		return idle_prompt
	return "Collect the %s for %s" % [pending.collected_label().to_lower(), pending.form_name]

func interact(player: Node) -> void:
	if pending == null:
		return
	var request := pending
	request.collected = true
	pending = null
	if _marker:
		_marker.visible = false
	if pickup_sound:
		_audio.stream = pickup_sound
		_audio.play()
	collected.emit(request)
	super.interact(player)
