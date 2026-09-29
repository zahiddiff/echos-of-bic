extends Node3D
class_name VisitorStage

## Who is physically in the building, and where.

const L := preload("res://code/world/building_layout.gd")

signal visitor_at_counter(request: VisitorRequest)

## The person currently at (or walking to) the counter.
var at_counter: VisitorFigure
var at_counter_request: VisitorRequest
## The next person, waiting just inside the doors.
var waiting: VisitorFigure
var waiting_request: VisitorRequest

var rahat: VisitorFigure
var dean: VisitorFigure
## Lockdown: nobody new comes in through the front.
var queue_closed: bool = false

## Where the player stands behind the counter — what people turn to face.
var player_point := Vector3(L.SEAT.x, 1.6, L.SEAT.z)

func _outside() -> Vector3:
	var e := L.entrance_centre()
	return Vector3(L.X_MAX + 3.0, 0.0, e.z)

func _threshold_out() -> Vector3:
	var e := L.entrance_centre()
	return Vector3(L.X_MAX + 1.2, 0.0, e.z)

func _threshold_in() -> Vector3:
	var e := L.entrance_centre()
	return Vector3(L.X_MAX - 0.9, 0.0, e.z)

## Detour so the walk from the queue to the counter never brushes the door sensor — a visitor stepping up to the desk should not open the doors.
func _approach() -> Vector3:
	return Vector3(L.QUEUE_SPOT.x, 0.0, L.VISITOR_SPOT.z - 0.35)

func counter_point() -> Vector3:
	return L.VISITOR_SPOT

func exit_point() -> Vector3:
	return L.entrance_centre() + Vector3(0, 1.4, 0)

# --- The queue ---------------------------------------------------------------------

## Call `request` to the counter.
func call_forward(request: VisitorRequest, upcoming: VisitorRequest = null) -> void:
	if request == null:
		return

	var figure: VisitorFigure
	if waiting and waiting_request == request:
		figure = waiting
		waiting = null
		waiting_request = null
		figure.walk(PackedVector3Array([_approach(), counter_point()]),
			_turn_to_player.bind(figure, request))
	else:
		figure = _spawn_outside(request)
		figure.walk(PackedVector3Array([_threshold_out(), _threshold_in(), _approach(), counter_point()]),
			_turn_to_player.bind(figure, request))

	at_counter = figure
	at_counter_request = request

	if upcoming and waiting == null:
		# The next person arrives a little later, so two people are never squeezing through the doors at once.
		get_tree().create_timer(2.5).timeout.connect(_admit_next.bind(upcoming))

func _admit_next(request: VisitorRequest) -> void:
	if queue_closed or waiting or request == at_counter_request:
		return
	var figure := _spawn_outside(request)
	waiting = figure
	waiting_request = request
	figure.walk(PackedVector3Array([_threshold_out(), _threshold_in(), L.QUEUE_SPOT]),
		func() -> void: figure.face(player_point))

## The visitor at the counter leaves the way they came.
func dismiss() -> void:
	var figure := at_counter
	at_counter = null
	at_counter_request = null
	if figure == null:
		return
	_walk_out(figure)

## The visitor at the counter is taken out by security.
func escort_out() -> void:
	var figure := at_counter
	at_counter = null
	at_counter_request = null
	if figure == null:
		return
	var guard := _make_guard()
	add_child(guard)
	guard.global_position = _outside()
	guard.face(_threshold_out(), true)
	var beside := counter_point() + Vector3(-0.55, 0, -0.15)
	guard.walk(PackedVector3Array([_threshold_out(), _threshold_in(), beside]), func() -> void:
		guard.face(figure.global_position)
		figure.face(guard.global_position)
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_walk_out(figure)
			get_tree().create_timer(0.6).timeout.connect(func() -> void: _walk_out(guard))))

## Anyone waiting in the queue leaves, and nobody else is let in.
func clear_waiting() -> void:
	queue_closed = true
	var figure := waiting
	waiting = null
	waiting_request = null
	if figure:
		_walk_out(figure)

## The Dean goes back out the way he came.
func dean_leaves() -> void:
	if is_instance_valid(dean):
		_walk_out(dean)
		dean = null

## Up the spine, through storage, into the meeting room: the dead end.
func meeting_room_route() -> PackedVector3Array:
	var x := L.doorway_centre_x()
	return PackedVector3Array([
		Vector3(x, 0.0, L.VISITOR_SPOT.z - 1.2),
		Vector3(x, 0.0, L.Z_STORAGE_MAIN - 0.6),
		Vector3(x, 0.0, L.Z_MEETING_STORAGE - 0.6),
		Vector3(x - 1.3, 0.0, L.Z_MIN + 1.4),
	])

## Stop where they stand.
func hold(figure: VisitorFigure) -> void:
	if is_instance_valid(figure):
		figure.walk(PackedVector3Array([figure.global_position]))

## Security come in and take `figure` out, wherever they are.
func escort_from(figure: VisitorFigure) -> VisitorFigure:
	if not is_instance_valid(figure):
		return null
	if figure == at_counter:
		at_counter = null
		at_counter_request = null
	hold(figure)
	var guard := _make_guard()
	add_child(guard)
	guard.global_position = _outside()
	guard.face(_threshold_out(), true)
	var beside := figure.global_position + (Vector3(L.X_MAX, 0, figure.global_position.z) - figure.global_position).normalized() * 0.7
	guard.walk(PackedVector3Array([_threshold_out(), _threshold_in(), beside]), func() -> void:
		guard.face(figure.global_position)
		figure.face(guard.global_position)
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_walk_out(figure)
			get_tree().create_timer(0.6).timeout.connect(func() -> void: _walk_out(guard))))
	return guard

## Round the open end of the counter, onto the staff side.
func staff_side_point() -> Vector3:
	return Vector3(L.COUNTER_X0 - 0.45, 0.0, L.counter_back_z() + 0.15)

## With the desk empty, the visitor at the counter drifts round to the staff side.
func slip_behind_counter() -> void:
	var figure := at_counter
	if figure == null or not is_instance_valid(figure):
		return
	var edge := Vector3(L.COUNTER_X0 - 0.45, 0.0, L.counter_front_z() - 0.3)
	figure.walk(PackedVector3Array([edge, staff_side_point()]), func() -> void:
		figure.face(Vector3(L.COUNTER_X1, 1.0, L.COUNTER_Z)))

## And back to where they should be, as if they never moved.
func step_back_to_counter() -> void:
	var figure := at_counter
	if figure == null or not is_instance_valid(figure):
		return
	var edge := Vector3(L.COUNTER_X0 - 0.45, 0.0, L.counter_front_z() - 0.3)
	figure.walk(PackedVector3Array([edge, counter_point()]), func() -> void: figure.face(player_point))

func is_behind_counter(figure: VisitorFigure) -> bool:
	return figure != null and figure.global_position.z > L.counter_front_z()

## Put someone at the counter with no walk and no door — nobody saw them come in, and the chime never played.
func appear_without_entering(request: VisitorRequest) -> VisitorFigure:
	var figure := VisitorFigure.for_request(request)
	add_child(figure)
	figure.global_position = counter_point()
	figure.face(player_point, true)
	at_counter = figure
	at_counter_request = request
	return figure

func _spawn_outside(request: VisitorRequest) -> VisitorFigure:
	var figure := VisitorFigure.for_request(request)
	add_child(figure)
	figure.global_position = _outside()
	figure.face(_threshold_out(), true)
	return figure

func _walk_out(figure: VisitorFigure) -> void:
	if not is_instance_valid(figure):
		return
	figure.walk(PackedVector3Array([_approach(), _threshold_in(), _threshold_out(), _outside()]),
		func() -> void:
			figure.departed.emit()
			figure.queue_free())

func _turn_to_player(figure: VisitorFigure, request: VisitorRequest) -> void:
	figure.face(player_point)
	visitor_at_counter.emit(request)

# --- Speaking ----------------------------------------------------------------------

## Route a line of dialogue to whoever is saying it.
func perform(line: DialogueLine, reading_speed: float) -> void:
	if line == null:
		return
	var who := _figure_for(line.speaker)
	if who == null:
		return
	var speaking := line.display_seconds(reading_speed)
	if who == rahat:
		rahat.address(player_point, line.lead_in + speaking)
		return
	who.perform(line.delivery, line.lead_in, speaking, exit_point())

func _figure_for(speaker: String) -> VisitorFigure:
	if speaker == Rahat.NAME:
		return rahat
	if speaker == Dean.NAME:
		return dean
	if at_counter_request and speaker == at_counter_request.visitor_name:
		return at_counter
	return null

# --- Cast -------------------------------------------------------------------------

## Prof.
func dean_arrives() -> void:
	dismiss()
	if is_instance_valid(dean):
		dean.queue_free()
	dean = VisitorFigure.new()
	dean.name = "Dean"
	dean.skin = Color(0.86, 0.73, 0.61)
	dean.hair = Color(0.56, 0.56, 0.57)
	dean.jacket = Color(0.14, 0.14, 0.16)
	dean.trousers = Color(0.12, 0.12, 0.14)
	dean.hair_style = PortraitFactory.Hair.SIDE_PART
	dean.glasses = true
	dean.stature = 1.04
	dean.walk_speed = 1.25
	add_child(dean)
	dean.global_position = _outside()
	dean.face(_threshold_out(), true)
	var figure := dean
	dean.walk(PackedVector3Array([_threshold_out(), _threshold_in(), _approach(), counter_point()]),
		func() -> void: figure.face(player_point))

func _make_guard() -> VisitorFigure:
	var guard := VisitorFigure.new()
	guard.name = "Security"
	guard.skin = Color(0.70, 0.55, 0.43)
	guard.hair = Color(0.10, 0.09, 0.09)
	guard.jacket = Color(0.12, 0.15, 0.24)
	guard.trousers = Color(0.08, 0.08, 0.10)
	guard.hair_style = PortraitFactory.Hair.BUZZ
	guard.stature = 1.06
	guard.walk_speed = 1.35
	return guard

func visitors_present() -> int:
	var total := 0
	for child in get_children():
		if child is VisitorFigure and child != rahat:
			total += 1
	return total
