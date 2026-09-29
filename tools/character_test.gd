extends Node

## Tests the people: construction, matching the ID photo, walking in through the real doors, the behavioural tells as body language, security escorts, Rahat at his desk and the Dean's arrival.
## Run: godot --headless --path <project> res://tools/character_test.tscn

const L := preload("res://code/world/building_layout.gd")
const BUILDING := "res://scenes/building/bic_building.tscn"

var _failures := 0
var _book: Rulebook

func _ready() -> void:
	_book = Rulebook.new()
	_book.current_date = "2026-09-17"
	_run()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _visitor(seed_value: int, name: String) -> VisitorRequest:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var request := RequestGenerator.new(_book, rng).clean_request(TaskPool.by_id("schedule_lookup"))
	request.visitor_name = name
	return request

func _run() -> void:
	print("Character test")
	await _test_construction()
	await _test_building_integration()

	print("")
	if _failures == 0:
		print("CHARACTER TEST PASSED")
	else:
		print("CHARACTER TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

# --- A figure, on its own ---------------------------------------------------------

func _test_construction() -> void:
	print("\n Building a person")
	var request := _visitor(4242, "Minho Choi")
	var figure := VisitorFigure.for_request(request)
	add_child(figure)
	await get_tree().process_frame

	for joint in ["torso", "head", "arm_l", "arm_r", "thigh_l", "thigh_r", "shin_l", "shin_r"]:
		_expect(figure.get(joint) is Node3D, "has a %s joint" % joint)
	_expect(figure.collision_layer == 2, "on the actors layer, so doors see them")

	# Their colouring comes from the face on their ID.
	var sampled := VisitorFigure.colours_from_portrait(request.visitor_portrait)
	_expect(figure.skin.is_equal_approx(sampled["skin"]), "skin matches the ID photo")
	_expect(figure.hair.is_equal_approx(sampled["hair"]), "hair matches the ID photo")
	_expect(figure.skin.get_luminance() > figure.hair.get_luminance(),
		"and the sample landed on skin, not hair")

	# Same name, same clothes — a visitor is recognisable across a shift.
	var again := VisitorFigure.for_request(request)
	_expect(again.jacket.is_equal_approx(figure.jacket), "clothing is stable for the same person")
	again.free()

	print("\n Tells are body language")
	var D := DialogueLine.Delivery
	figure.global_position = L.VISITOR_SPOT
	figure.face(Vector3(L.SEAT.x, 0, L.SEAT.z), true)
	var exit := L.entrance_centre() + Vector3(0, 1.4, 0)

	figure.perform(D.CHECKS_EXIT, 0.0, 1.5, exit)
	await _wait(0.45)
	_expect(absf(figure.head.rotation.y) > 0.5,
		"checks the exit: the head turns to the doors (%.0f°)" % rad_to_deg(figure.head.rotation.y))
	var toward := figure.to_global(Vector3(0, 0, -1).rotated(Vector3.UP, figure.head.rotation.y)) - figure.global_position
	var to_door := exit - figure.global_position
	_expect(Vector2(toward.x, toward.z).dot(Vector2(to_door.x, to_door.z)) > 0.0,
		"and it turns TOWARD the doors, not away")
	await _wait(1.6)

	figure.perform(D.CHECKS_TIME, 0.0, 1.5, exit)
	await _wait(0.45)
	_expect(figure.arm_l.rotation.x < -0.8, "checks the time: the wrist comes up")
	_expect(figure.head.rotation.x < -0.2, "and the eyes go down to it")
	await _wait(1.6)

	figure.perform(D.GOES_QUIET, 0.5, 1.5, exit)
	await _wait(0.8)
	_expect(figure.head.rotation.x < -0.25, "goes quiet: head down")
	_expect(absf(figure.head.rotation.y) > 0.2, "gaze off to one side")
	await _wait(2.2)

	figure.perform(D.TOO_FAST, 0.0, 1.0, exit)
	await _wait(0.2)
	_expect(figure.torso.rotation.x < -0.08, "answers too fast: leans in")
	await _wait(1.4)

	figure.perform(D.OVER_EXPLAINS, 0.0, 2.0, exit)
	await _wait(0.3)
	_expect(minf(figure.arm_l.rotation.x, figure.arm_r.rotation.x) < -0.3,
		"over-explains: the hands start going")
	await _wait(2.2)

	figure.perform(D.HESITANT, 1.2, 1.0, exit)
	await _wait(0.6)
	_expect(figure.head.rotation.x < -0.08, "hesitates: a drop of the head through the silence")

	figure.queue_free()
	await get_tree().process_frame

# --- In the building ----------------------------------------------------------------

func _test_building_integration() -> void:
	print("\n In the building")
	GameState.reset()
	GameState.set_player_name("Zahidul")

	var building: BICBuilding = load(BUILDING).instantiate()
	building.shift = 2
	building.queue_seed = 2468
	add_child(building)

	var opened := [0]
	building.entrance.opened.connect(func() -> void: opened[0] += 1)
	var at_counter: Array = []
	building.stage.visitor_at_counter.connect(func(r: VisitorRequest) -> void: at_counter.append(r))

	# Rahat is at his desk, sitting, on an ordinary shift.
	var rahat := building.stage.rahat
	_expect(rahat != null, "Rahat is at his desk")
	if rahat:
		_expect(rahat.pose == VisitorFigure.Pose.SEATED, "sitting down")
		_expect(rahat.is_visible_in_tree(), "and visible on shift 2")

	await _wait(0.2)
	var first := building.stage.at_counter
	_expect(first != null, "the first visitor is on their way in")
	if first:
		_expect(first.global_position.x > L.X_MAX, "starting outside the building")

	await _wait(7.0)
	_expect(opened[0] >= 1, "walking in through the doors opened them — and chimed")
	_expect(at_counter.size() >= 1, "they reached the counter")
	if first:
		var at := Vector2(first.global_position.x, first.global_position.z)
		_expect(at.distance_to(Vector2(L.VISITOR_SPOT.x, L.VISITOR_SPOT.z)) < 0.1,
			"standing across the counter from the player")
		var facing := Vector3(0, 0, -1).rotated(Vector3.UP, first.rotation.y)
		_expect(facing.z > 0.8, "facing the player")
	_expect(building.stage.at_counter_request == building.current_request(),
		"and they are the person whose paperwork is on the desk")
	_expect(building.stage.waiting != null, "the next person has come in to wait")

	await _wait(building.entrance.close_delay + building.entrance.slide_time + 0.6)
	_expect(not building.entrance.is_open,
		"someone standing at the counter does not hold the doors open")

	# An ordinary decision: they walk out.
	var leaving := building.stage.at_counter
	var request := building.current_request()
	var ticket := VisitorTicket.of(request)
	add_child(ticket)
	building._resolve(ticket, BICBuilding.Decision.APPROVE, "test")
	await _wait(0.3)
	_expect(building.stage.at_counter != leaving, "after a decision the next visitor steps up")
	await _wait(7.0)
	_expect(not is_instance_valid(leaving), "and the last one has walked out and gone")

	# A flag: security walk in and take them.
	await _wait(1.5)
	var flagged := building.stage.at_counter
	var flag_ticket := VisitorTicket.of(building.current_request())
	add_child(flag_ticket)
	building._resolve(flag_ticket, BICBuilding.Decision.FLAG, "test")
	await _wait(0.4)
	var guard := building.stage.get_node_or_null("Security")
	_expect(guard != null, "flagging someone brings security in")
	# Security walk in (~4 s), a beat at the counter, then ~6 s back out.
	await _wait(13.0)
	_expect(not is_instance_valid(flagged), "and they are taken out")

	# The Dean.
	building.stage.dean_arrives()
	await _wait(0.2)
	_expect(building.stage.dean != null, "after an incident the Dean comes to the desk")
	if building.stage.dean:
		_expect(building.stage.dean.hair.get_luminance() > 0.4, "grey-haired, as the cast describes")

	# Nobody saw them come in.
	var before: int = opened[0]
	await _wait(3.0)
	before = opened[0]
	var ghost := building.stage.appear_without_entering(_visitor(99, "Nobody"))
	await _wait(1.5)
	_expect(opened[0] == before,
		"appear_without_entering puts someone at the desk with no door and no chime")
	_expect(ghost.global_position.distance_to(L.VISITOR_SPOT) < 0.05, "right at the counter")

	# Rahat stops being there — and stops being solid.
	GameState.shift = 6
	building.story.refresh()
	await get_tree().process_frame
	if rahat:
		_expect(not rahat.is_visible_in_tree(), "shift 6: Rahat is gone with his things")
		_expect(rahat.collision_layer == 0, "and there is no invisible Rahat to bump into")

	building.queue_free()
	await get_tree().process_frame
