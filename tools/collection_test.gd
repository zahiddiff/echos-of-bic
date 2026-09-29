extends Node

## Tests physical tasks: fetching from the print room before approving, what comes back, and what a thief does with the empty desk.
## Run: godot --headless --path <project> res://tools/collection_test.tscn

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
	print("Collection test")
	_test_judging()
	await _test_fetch_loop()
	await _test_thief_uses_the_empty_desk()

	print("")
	if _failures == 0:
		print("COLLECTION TEST PASSED")
	else:
		print("COLLECTION TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _building(shift: int, with_people: bool) -> BICBuilding:
	var building: BICBuilding = load(BUILDING).instantiate()
	building.shift = shift
	building.queue_seed = 4040
	building.visitors_enabled = with_people
	building.decision_pause = 0.0
	building.reload_on_continue = false
	add_child(building)
	building.dialogue.reading_speed = 600.0
	building.dialogue.silence_padding = 0.02
	await get_tree().process_frame
	return building

func _point(building: BICBuilding, kind: String) -> CollectionPoint:
	for point in building.collection_points:
		if point.kind == kind:
			return point
	return null

# --- What comes back --------------------------------------------------------------------

func _test_judging() -> void:
	print("\n What comes back from the back room")
	var book := Rulebook.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var maker := RequestGenerator.new(book, rng)
	var author := WrongnessAuthor.new(book, rng)
	var all_labelled := true
	for task in TaskPool.physical_tasks():
		if TaskPool.collection_label(task.id).is_empty():
			all_labelled = false
	_expect(all_labelled, "every physical task has something waiting in the print room")

	var wrong := maker.clean_request(TaskPool.by_id("bank_letter"))
	author.apply(wrong, VisitorRequest.Wrongness.PHYSICAL)
	_expect(not wrong.collection_matches(), "Physical Wrongness: the letter doesn't match the form")
	_expect(DecisionJudge.judge(wrong, DecisionJudge.APPROVE, book) == DecisionJudge.Verdict.PROCESSING_ERROR,
		"handing it over anyway is a mistake")
	_expect(DecisionJudge.judge(wrong, DecisionJudge.REJECT, book) == DecisionJudge.Verdict.CORRECT,
		"turning it down is right")

# --- The walk ----------------------------------------------------------------------------

func _test_fetch_loop() -> void:
	print("\n Fetching a printout (training shift, visitor 4)")
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var building := await _building(1, false)
	for i in 3:
		building.runner.resolve(DecisionJudge.APPROVE)
		await get_tree().process_frame
	var request := building.current_request()
	_expect(request != null and request.task_id == "transcript_print", "the fourth visitor wants a transcript printed")
	var printer := _point(building, "printout")
	var shelf := _point(building, "parcel")
	_expect(printer != null and shelf != null, "the print room has a printer and a mailroom shelf")
	_expect(printer.pending == request and shelf.pending == null, "the transcript is waiting at the printer, not the shelf")
	_expect(printer.get_prompt().contains("transcript"), "the printer says what it is holding (%s)" % printer.get_prompt())

	var decisions: Array = []
	building.decision_made.connect(func(_r: VisitorRequest, d: int) -> void: decisions.append(d))

	building.desk.sit(building.player)
	await get_tree().process_frame
	_expect(building.stamp.locked, "the stamp is locked until the transcript is fetched")
	_expect(building.viewer._collect_row.visible and not building.viewer.item_paper.visible,
		"the form says it's waiting in the back room")
	building._on_desk_action_clicked(building.stamp)
	await get_tree().process_frame
	_expect(decisions.is_empty(), "clicking the stamp early approves nothing")
	_expect(building.viewer.hint_label.text.contains("print room"), "and the desk says where to go")

	building.desk.stand()
	await get_tree().process_frame
	printer.interact(building.player)
	_expect(request.collected and printer.pending == null, "picking it up at the printer")

	building.desk.sit(building.player)
	await get_tree().process_frame
	_expect(not building.stamp.locked, "back at the desk the stamp works")
	_expect(building.viewer.item_paper.visible, "and the printout is on the desk")
	_expect(building.viewer._item_name.text == request.form_name, "printed under the right name")
	building._on_desk_action_clicked(building.stamp)
	await get_tree().process_frame
	_expect(decisions == [BICBuilding.Decision.APPROVE], "then it can be approved")
	var shift: Dictionary = (PlaytestLog.session["shifts"] as Array).back()
	var logged: Dictionary = (shift["visitors"] as Array).back()
	_expect(logged.get("collected", false) and logged["verdict"] == "CORRECT", "the log shows the walk and the right call")

	building.queue_free()
	await get_tree().process_frame

# --- The empty desk ---------------------------------------------------------------------

func _test_thief_uses_the_empty_desk() -> void:
	print("\n A thief and the empty desk")
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var building := await _building(2, true)
	var request := building.current_request()
	# Make whoever is first a thief with a parcel to fetch.
	request.task_id = "mail_pickup"
	request.is_threat = true
	request.threat_kind = ThreatType.Kind.THIEF
	request.collected = false
	building._refresh_collection()
	await _wait(9.0)
	var figure := building.stage.at_counter
	_expect(figure != null and figure.global_position.distance_to(L.VISITOR_SPOT) < 0.2, "they are waiting at the counter")

	building.desk.sit(building.player)
	await get_tree().process_frame
	building.desk.stand()
	await _wait(8.5)
	_expect(building.stage.is_behind_counter(figure), "with the desk empty they come round to the staff side")

	_point(building, "parcel").interact(building.player)
	await _wait(6.0)
	_expect(not building.stage.is_behind_counter(figure) and figure.global_position.distance_to(L.VISITOR_SPOT) < 0.3,
		"when you come back with the parcel they are at the counter again")

	# An ordinary visitor never wanders.
	GameState.reset()
	building.queue_free()
	await get_tree().process_frame
	GameState.set_player_name("Zahidul")
	building = await _building(2, true)
	request = building.current_request()
	request.task_id = "mail_pickup"
	request.is_threat = false
	request.threat_kind = ThreatType.Kind.NONE
	building._refresh_collection()
	await _wait(9.0)
	figure = building.stage.at_counter
	building.desk.sit(building.player)
	await get_tree().process_frame
	building.desk.stand()
	await _wait(8.5)
	_expect(figure != null and not building.stage.is_behind_counter(figure), "an ordinary visitor just waits")
	building.queue_free()
	await get_tree().process_frame
	GameState.reset()
