extends Node

## Tests the last night: the fifth incident becomes a lockdown, someone gets past it, and the radio is the only thing that stops them.
## Run: godot --headless --path <project> res://tools/finale_test.tscn

const BUILDING := "res://scenes/building/bic_building.tscn"
const L := preload("res://code/world/building_layout.gd")

var _failures := 0

func _ready() -> void:
	_run()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _run() -> void:
	print("Finale test")
	_test_the_visitor()
	await _test_radio_first()
	await _test_stamped_anyway()

	print("")
	if _failures == 0:
		print("FINALE TEST PASSED")
	else:
		print("FINALE TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _test_the_visitor() -> void:
	print("\n The last visitor")
	var book := Rulebook.new()
	var request := Finale.build_request(book, 77)
	_expect(book.passes(request) and request.collection_matches(), "their paperwork passes every rule")
	_expect(request.is_threat and request.threat_kind == ThreatType.Kind.FINALE, "and they are the Finale Threat")
	_expect(DecisionJudge.right_call(request, book) == DecisionJudge.RightCall.FLAG, "the right call is the radio")
	var record := "\n".join(Finale.record_lines(request))
	_expect(record.contains("WITHDRAWN") and record.contains("REPORTED LOST"), "the records terminal says the card isn't theirs")
	_expect(not ThreatType.RANDOM_KINDS.has(ThreatType.Kind.FINALE), "and they never turn up in an ordinary queue")

## A run with four strikes, and a missed threat about to become the fifth.
func _last_night() -> BICBuilding:
	GameState.reset()
	GameState.set_player_name("Zahidul")
	GameState.strikes_taken = GameState.MAX_STRIKES - 1
	var building: BICBuilding = load(BUILDING).instantiate()
	building.shift = 7
	building.queue_seed = 9090
	building.visitors_enabled = true
	building.decision_pause = 0.0
	building.reload_on_continue = false
	add_child(building)
	building.dialogue.reading_speed = 600.0
	building.dialogue.silence_padding = 0.02
	await get_tree().process_frame
	return building

func _start_finale(building: BICBuilding) -> Array:
	var chimes: Array = [0]
	building.entrance.opened.connect(func() -> void: chimes[0] += 1)
	building.runner._run_incident(building.runner.current())
	await get_tree().process_frame
	_expect(building.runner.in_finale and not building.runner.shift_over, "the fifth incident starts the lockdown, not the end of the shift")
	_expect(GameState.strikes_taken == GameState.MAX_STRIKES, "it is the fifth strike")
	var waited := 0.0
	while building.finale_request == null and waited < 45.0:
		await _wait(0.5)
		waited += 0.5
	_expect(building.entrance.locked, "the front doors are locked")
	_expect(building.finale_request != null, "someone is at the desk anyway")
	chimes[0] = 0
	await _wait(1.0)
	var figure := building.finale_figure
	_expect(figure != null and figure.global_position.distance_to(L.VISITOR_SPOT) < 0.2, "standing at the counter")
	_expect(chimes[0] == 0, "and the doors never opened for them")
	return chimes

func _test_radio_first() -> void:
	print("\n Calling it in")
	var building := await _last_night()
	await _start_finale(building)
	building.desk.sit(building.player)
	await get_tree().process_frame
	_expect(building.viewer.visible and building.viewer.request == building.finale_request, "their papers are on the desk")
	building._on_desk_action_clicked(building.radio)
	await _wait(11.0)
	_expect(building._finale_walking, "they hear the radio and start walking")
	await _wait(7.0)
	_expect(building.finale_outcome == Finale.Outcome.STOPPED, "security stop them before the meeting room")
	var waited := 0.0
	while not building.report.is_showing and waited < 30.0:
		await _wait(0.5)
		waited += 0.5
	_expect(building.report.is_showing and building.report.summary.get("finale") == Finale.Outcome.STOPPED,
		"the shift report tells it")
	building._on_report_continue()
	_expect(GameState.run_over and GameState.ending == GameState.Ending.FIRED, "five is still five: fired")
	_expect(building.report.mode == "ending", "the ending plays")
	building.queue_free()
	await get_tree().process_frame

func _test_stamped_anyway() -> void:
	print("\n Handing over the key")
	var building := await _last_night()
	await _start_finale(building)
	building.desk.sit(building.player)
	await get_tree().process_frame
	building._on_desk_action_clicked(building.stamp)
	await _wait(4.0)
	_expect(building._finale_walking, "stamped, they head for the meeting room")
	var figure := building.finale_figure
	await _wait(3.0)
	building._on_desk_action_clicked(building.radio)
	await _wait(14.0)
	_expect(building.finale_outcome == Finale.Outcome.REACHED, "the radio after the stamp is too late: they reach the meeting room")
	_expect(figure.global_position.z < L.Z_MEETING_STORAGE, "they are in the meeting room")
	var waited := 0.0
	while not building.report.is_showing and waited < 30.0:
		await _wait(0.5)
		waited += 0.5
	building._on_report_continue()
	_expect(building.report.mode == "ending" and GameState.finale_outcome == Finale.Outcome.REACHED,
		"and the ending is the one where they got there")
	building.queue_free()
	await get_tree().process_frame
	GameState.reset()
