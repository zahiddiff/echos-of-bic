extends Node

## Tests the playtest pipeline: the building fills the log correctly, and the analysis reads it back into sensible numbers.
## Run: godot --headless --path <project> res://tools/playtest_test.tscn

const BUILDING := "res://scenes/building/bic_building.tscn"

var _failures := 0

func _ready() -> void:
	_run()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

func _run() -> void:
	print("Playtest test")
	await _test_building_fills_the_log()
	_test_analysis()

	print("")
	if _failures == 0:
		print("PLAYTEST TEST PASSED")
	else:
		print("PLAYTEST TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

# --- The log, from a real shift -----------------------------------------------------

func _test_building_fills_the_log() -> void:
	print("\n A shift in the building")
	_expect(not PlaytestLog.persist, "headless runs keep the log in memory only")
	GameState.reset()
	GameState.set_player_name("Tester")
	PlaytestLog.start_session()

	var building: BICBuilding = load(BUILDING).instantiate()
	building.shift = 3
	building.queue_seed = 777
	building.visitors_enabled = false
	building.decision_pause = 0.0
	building.reload_on_continue = false
	add_child(building)
	building.dialogue.reading_speed = 600.0
	building.dialogue.silence_padding = 0.02
	await get_tree().process_frame

	var book := building.rulebook
	var missed_one := false
	var decisions: Array[String] = []
	var guard := 0
	while building.runner.current() != null and not building.runner.shift_over and guard < 40:
		guard += 1
		var request := building.runner.current()
		building._on_desk_seated(building.player)
		if guard % 2 == 0:
			PlaytestLog.note("follow_up")
		if guard == 1:
			PlaytestLog.note("magnifier")
		var decision := BICBuilding.Decision.APPROVE
		if request.is_threat and missed_one:
			decision = BICBuilding.Decision.FLAG
		elif request.is_threat:
			missed_one = true
		elif DecisionJudge.was_catchable_at_desk(request, book):
			decision = BICBuilding.Decision.REJECT
		decisions.append(["APPROVE", "REJECT", "FLAG"][decision])
		building._resolve(building._ticket, decision, "")
		await get_tree().process_frame

	var shifts: Array = PlaytestLog.session["shifts"]
	_expect(shifts.size() == 1, "one shift in the log")
	var shift: Dictionary = shifts[0]
	_expect(int(shift["shift"]) == 3, "it is shift 3")
	_expect(int(shift["queue_size"]) == building.runner.queue.size(), "with the queue size")
	var visitors: Array = shift["visitors"]
	_expect(visitors.size() == building.runner.index, "every visitor served is logged (%d of %d)" % [visitors.size(), building.runner.index])
	var in_order := true
	for i in visitors.size():
		if visitors[i]["decision"] != decisions[i] or str(visitors[i]["verdict"]).is_empty():
			in_order = false
	_expect(in_order, "each with the decision taken and a verdict")
	_expect(visitors.size() > 0 and bool(visitors[0]["magnified"]), "the magnifier is noted on the right visitor")
	_expect(visitors.size() > 1 and int(visitors[1]["follow_ups"]) == 1, "and so are follow-ups")
	var misses := visitors.filter(func(v: Dictionary) -> bool: return v["verdict"] == "MISSED_THREAT")
	_expect(misses.size() >= 1 and not str(misses[0]["threat"]).is_empty(), "the missed threat is logged with its kind")
	var clean := visitors.filter(func(v: Dictionary) -> bool: return v["wrongness"] == "NONE" and v["threat"] == "")
	_expect(clean.all(func(v: Dictionary) -> bool: return (v["broken_rules"] as Array).is_empty()),
		"clean paperwork breaks no rules in the log")

	var waited := 0.0
	while not building.report.is_showing and waited < 40.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_expect(not str(shift["end_reason"]).is_empty(), "the shift's end is logged (%s)" % shift["end_reason"])
	_expect(shift["events"].any(func(e: Dictionary) -> bool: return e["kind"] == "incident") == (shift["end_reason"] == "INCIDENT"),
		"an incident shows up as an event exactly when it ended the shift")

	building.report.feedback = {"tension": 4, "felt_fake": "the queue", "confusing": ""}
	building._on_report_continue()
	_expect(int(shift["feedback"]["tension"]) == 4, "post-shift answers land on that shift")

	var parsed: Variant = JSON.parse_string(PlaytestLog.to_json())
	_expect(parsed is Dictionary and (parsed["shifts"] as Array).size() == 1, "the log is valid JSON")
	_expect(not PlaytestLog.to_json().contains("started_ms"), "without internal timers in it")
	_expect(not PlaytestLog.to_json().contains("Tester"), "and without the player's name")
	# Left behind for tools/playtest_report.gd to be tried on.
	DirAccess.make_dir_recursive_absolute("user://playtest-sample")
	var sample := FileAccess.open("user://playtest-sample/session-test.json", FileAccess.WRITE)
	if sample:
		sample.store_string(PlaytestLog.to_json())

	building.queue_free()
	await get_tree().process_frame

# --- The analysis ----------------------------------------------------------------------

## Whole runs by a scripted player, logged exactly as the building logs them.
func _bot_sessions(catch_rate: float, false_flag_rate: float, runs: int, seed_value: int) -> Array:
	var sessions: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var book := Rulebook.new()
	book.current_date = "2026-09-17"
	for run in runs:
		GameState.reset()
		GameState.set_player_name("Bot")
		PlaytestLog.start_session()
		var runner := ShiftRunner.new()
		runner.rulebook = book
		runner.generate_portraits = false
		add_child(runner)
		runner.shift_started.connect(func(n: int, count: int) -> void:
			PlaytestLog.begin_shift(n, ShiftSchedule.is_onboarding(n), count, GameState.strikes_remaining()))
		runner.decision_judged.connect(func(r: VisitorRequest, verdict: DecisionJudge.Verdict) -> void:
			PlaytestLog.decision_judged(r, verdict, PackedStringArray()))
		runner.shift_ended.connect(func(reason: ShiftRunner.EndReason) -> void:
			PlaytestLog.end_shift(ShiftRunner.EndReason.keys()[reason], GameState.strikes_remaining()))
		var played := 0
		while not GameState.run_over and played < ShiftSchedule.TOTAL_SHIFTS:
			runner.start(GameState.shift, rng.randi())
			played += 1
			var guard := 0
			while not runner.shift_over and runner.current() != null and guard < 40:
				guard += 1
				var request := runner.current()
				var decision := DecisionJudge.APPROVE
				if request.is_threat:
					decision = DecisionJudge.FLAG if rng.randf() < catch_rate else DecisionJudge.APPROVE
				elif rng.randf() < false_flag_rate:
					decision = DecisionJudge.FLAG
				elif DecisionJudge.was_catchable_at_desk(request, book):
					decision = DecisionJudge.REJECT
				PlaytestLog.visitor_shown(request, runner.index)
				if request.is_threat and rng.randf() < 0.5:
					PlaytestLog.note("follow_up")
				PlaytestLog.decision_made(decision)
				runner.resolve(decision)
			PlaytestLog.shift_feedback({"tension": clampi(1 + played / 2, 1, 5), "felt_fake": "", "confusing": ""})
			runner.close_out()
		PlaytestLog.end_run(GameState.ending_name(GameState.ending) if GameState.run_over else "")
		sessions.append(PlaytestLog.session.duplicate(true))
		runner.free()
	GameState.reset()
	return sessions

func _test_analysis() -> void:
	print("\n Reading logs back")
	var careful := PlaytestAnalysis.summarise(_bot_sessions(0.8, 0.02, 12, 11))
	var careless := PlaytestAnalysis.summarise(_bot_sessions(0.3, 0.2, 12, 11))
	var careful_rates := PlaytestAnalysis.rates(careful)
	var careless_rates := PlaytestAnalysis.rates(careless)

	_expect(careful["sessions"] == 12 and careful["threats"] > 20, "counts sessions and threat encounters (%d)" % careful["threats"])
	_expect(absf(careful_rates["miss_rate"] - 0.2) < 0.12,
		"a player who catches 80%% misses about 20%% (%.2f)" % careful_rates["miss_rate"])
	_expect(careless_rates["miss_rate"] > careful_rates["miss_rate"] + 0.25, "a careless player misses far more")
	_expect(absf(careless_rates["false_flag_rate"] - 0.2) < 0.08,
		"false flags are measured against innocents (%.2f)" % careless_rates["false_flag_rate"])
	_expect(careful_rates["processing_error_rate"] == 0.0, "a player following the rulebook makes no paperwork errors")
	_expect(careless["endings"].has("Fired"), "careless runs end in firing")

	var advice := "\n".join(PlaytestAnalysis.recommendations(careless))
	_expect(advice.contains("THREAT_TELL_CHANCE"), "too many misses points at the tell chance")
	_expect(advice.contains("INNOCENT_TELL_CHANCE"), "too many false flags points at innocent tells")
	var calm := "\n".join(PlaytestAnalysis.recommendations(careful))
	_expect(not calm.contains("get through"), "a careful player's misses are inside the target")

	var md := PlaytestAnalysis.to_markdown(careful, "Test")
	_expect(md.contains("| Threats missed |") and md.contains("## By shift"), "the report has its tables")
	_expect(PlaytestAnalysis.summarise([])["threats"] == 0 and not PlaytestAnalysis.to_markdown(PlaytestAnalysis.summarise([])).is_empty(),
		"an empty folder still gives a report")
