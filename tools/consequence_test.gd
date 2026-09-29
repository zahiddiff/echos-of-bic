extends Node

## Tests judging calls, the delayed incident, the Dean, strikes and endings.
## Run: godot --headless --path <project> res://tools/consequence_test.tscn

var _failures := 0
var _book: Rulebook

func _ready() -> void:
	_book = Rulebook.new()
	_book.current_date = "2026-09-17"

	_test_threat_catalogue()
	_test_judging()
	_test_delayed_incident()
	_test_strikes_and_endings()
	_test_false_flags()
	_test_dean_escalation()

	print("")
	if _failures == 0:
		print("CONSEQUENCE TEST PASSED")
	else:
		print("CONSEQUENCE TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

func _clean() -> VisitorRequest:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return RequestGenerator.new(_book, rng).clean_request(TaskPool.by_id("room_lookup"))

func _threat(kind: ThreatType.Kind = ThreatType.Kind.STALKER) -> VisitorRequest:
	var request := _clean()
	request.is_threat = true
	request.threat_kind = kind
	return request

# --- Threat catalogue ---------------------------------------------------------

func _test_threat_catalogue() -> void:
	print("Threat catalogue")
	_expect(ThreatType.RANDOM_KINDS.size() == 3,
		"three threat types are shuffled into the queue")
	_expect(not ThreatType.RANDOM_KINDS.has(ThreatType.Kind.FINALE),
		"the Finale Threat is never in the random pool")
	_expect(ThreatType.is_designed(ThreatType.Kind.FINALE),
		"the Finale Threat is written (the lockdown)")

	for kind in ThreatType.RANDOM_KINDS:
		var covers := ThreatType.cover_task_ids(kind)
		var probes := ThreatType.probes_for(kind)
		_expect(covers.size() >= 3 and probes.size() >= 1,
			"%s has cover errands (%d) and a probe question (%d)"
				% [ThreatType.label(kind), covers.size(), probes.size()])
		var all_real := true
		for task_id: String in covers:
			if TaskPool.by_id(task_id) == null:
				all_real = false
		_expect(all_real, "%s's cover errands are all real tasks" % ThreatType.label(kind))

	# Equal weighting, per the design.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var counts := {}
	for i in 900:
		var kind := ThreatType.pick_random(rng)
		counts[kind] = counts.get(kind, 0) + 1
	var balanced := true
	for kind in ThreatType.RANDOM_KINDS:
		if counts.get(kind, 0) < 240 or counts.get(kind, 0) > 360:
			balanced = false
	_expect(balanced, "the three are drawn with roughly equal weight %s" % str(counts.values()))

	# Generated threats should be on errands that suit them.
	var queue := QueueGenerator.new(_book, 616).build_shift(8)
	var mismatched := 0
	var kinds_seen := {}
	for request in queue:
		if not request.is_threat:
			continue
		kinds_seen[request.threat_kind] = true
		var covers := ThreatType.cover_task_ids(request.threat_kind)
		if not covers.is_empty() and not covers.has(request.task_id):
			mismatched += 1
	_expect(mismatched == 0, "every generated threat is on a fitting cover errand")
	_expect(kinds_seen.size() >= 1, "generated threats carry a specific kind")

# --- Judging ------------------------------------------------------------------

func _test_judging() -> void:
	print("\nJudging a call")
	var V := DecisionJudge.Verdict

	var clean := _clean()
	_expect(_book.passes(clean), "the test's clean visitor really is clean")
	_expect(DecisionJudge.judge(clean, DecisionJudge.APPROVE, _book) == V.CORRECT,
		"approving a clean visitor is correct")
	_expect(DecisionJudge.judge(clean, DecisionJudge.REJECT, _book) == V.PROCESSING_ERROR,
		"rejecting a clean visitor is bad work, not an incident")
	_expect(DecisionJudge.judge(clean, DecisionJudge.FLAG, _book) == V.FALSE_FLAG,
		"calling security on a clean visitor is a false flag")

	var invalid := _clean()
	invalid.college_code = "ZZZ"
	_expect(DecisionJudge.judge(invalid, DecisionJudge.REJECT, _book) == V.CORRECT,
		"rejecting invalid paperwork is correct")
	_expect(DecisionJudge.judge(invalid, DecisionJudge.APPROVE, _book) == V.PROCESSING_ERROR,
		"approving invalid paperwork is bad work")
	_expect(DecisionJudge.judge(invalid, DecisionJudge.FLAG, _book) == V.FALSE_FLAG,
		"bad paperwork alone does not make someone a threat")

	var threat := _threat()
	_expect(DecisionJudge.judge(threat, DecisionJudge.FLAG, _book) == V.CORRECT,
		"flagging a threat is the right call")
	_expect(DecisionJudge.judge(threat, DecisionJudge.APPROVE, _book) == V.MISSED_THREAT,
		"approving a threat is a missed threat")
	_expect(DecisionJudge.judge(threat, DecisionJudge.REJECT, _book) == V.MISSED_THREAT,
		"rejecting a threat is ALSO a missed threat — turning them away is not stopping them")

# --- The delay ----------------------------------------------------------------

func _test_delayed_incident() -> void:
	print("\nA missed threat surfaces late, not immediately")
	GameState.reset()
	GameState.set_player_name("Zahidul")

	var runner := ShiftRunner.new()
	runner.rulebook = _book
	add_child(runner)

	var incidents: Array = []
	var dean_visits: Array = []
	var ended: Array = []
	runner.incident_occurred.connect(func(r: VisitorRequest) -> void: incidents.append(r))
	runner.dean_arrived.connect(
		func(lines: PackedStringArray, n: int) -> void: dean_visits.append([lines, n]))
	runner.shift_ended.connect(func(reason: int) -> void: ended.append(reason))

	runner.start(6, 90210)
	var served := 0
	var missed: VisitorRequest = null

	while runner.current() != null and not runner.shift_over:
		var visitor := runner.current()
		if visitor.is_threat and missed == null:
			missed = visitor
			runner.resolve(DecisionJudge.APPROVE)   # wave the threat through
			_expect(incidents.is_empty(),
				"nothing happens at the moment the threat is approved")
			_expect(GameState.strikes_taken == 0, "and no strike lands yet")
		else:
			runner.resolve(DecisionJudge.APPROVE)
		served += 1
		if served > 40:
			break

	_expect(missed != null, "the shift contained a threat to miss")
	_expect(incidents.size() == 1, "the incident does eventually happen")
	if incidents.size() == 1:
		_expect(incidents[0] == missed, "and it is traced to the visitor who was waved through")
	_expect(dean_visits.size() == 1, "the Dean arrives after the incident")
	_expect(GameState.strikes_taken == 1, "it costs exactly one strike")
	_expect(ended.size() == 1 and ended[0] == ShiftRunner.EndReason.INCIDENT,
		"and the shift ends early")
	_expect(runner.visitors_remaining() > 0,
		"the rest of the night's quota is lost (%d visitors unserved)" % runner.visitors_remaining())

	runner.queue_free()

func _test_clean_shift_runs_out() -> void:
	pass

# --- Strikes and endings ------------------------------------------------------

func _test_strikes_and_endings() -> void:
	print("\nStrikes and endings")
	GameState.reset()
	_expect(GameState.strikes_remaining() == 5, "a run starts with five strikes")
	_expect(GameState.is_flawless(), "and a clean record")

	var seen: Array = []
	GameState.run_ended.connect(func(e: int) -> void: seen.append(e))

	for i in 4:
		GameState.take_strike()
	_expect(GameState.strikes_remaining() == 1, "four strikes leaves one")
	_expect(seen.is_empty(), "the run is not over yet")
	GameState.take_strike()
	_expect(seen.size() == 1 and seen[0] == GameState.Ending.FIRED,
		"the fifth strike ends the run as Fired")
	_expect(GameState.run_over, "and the run is marked over")

	GameState.take_strike()
	_expect(seen.size() == 1, "further strikes after being fired change nothing")

	# Standard: finish shift 8 with at least one strike left.
	GameState.reset()
	var standard: Array = []
	GameState.run_ended.connect(func(e: int) -> void: standard.append(e))
	GameState.take_strike()
	GameState.take_strike()
	for i in ShiftSchedule.TOTAL_SHIFTS:
		GameState.advance_shift()
	_expect(standard.size() == 1 and standard[0] == GameState.Ending.STANDARD,
		"finishing with strikes left gives the Standard ending")

	# True: finish shift 8 having never taken one.
	GameState.reset()
	var flawless: Array = []
	GameState.run_ended.connect(func(e: int) -> void: flawless.append(e))
	for i in ShiftSchedule.TOTAL_SHIFTS:
		GameState.advance_shift()
	_expect(flawless.size() == 1 and flawless[0] == GameState.Ending.TRUE_END,
		"finishing without a single strike gives the True ending")
	_expect(GameState.ending_name(GameState.Ending.TRUE_END) == "True", "endings are nameable")

	# The flag-everyone route: no strikes, but security called on half the building.
	GameState.reset()
	var paranoid: Array = []
	GameState.run_ended.connect(func(e: int) -> void: paranoid.append(e))
	for i in GameState.TRUE_ENDING_FALSE_FLAG_ALLOWANCE + 1:
		GameState.record_false_flag()
	for i in ShiftSchedule.TOTAL_SHIFTS:
		GameState.advance_shift()
	_expect(paranoid.size() == 1 and paranoid[0] == GameState.Ending.STANDARD,
		"no strikes but too many false flags gives Standard, not True")

	# A couple of honest mistakes are forgiven.
	GameState.reset()
	var forgiven: Array = []
	GameState.run_ended.connect(func(e: int) -> void: forgiven.append(e))
	for i in GameState.TRUE_ENDING_FALSE_FLAG_ALLOWANCE:
		GameState.record_false_flag()
	for i in ShiftSchedule.TOTAL_SHIFTS:
		GameState.advance_shift()
	_expect(forgiven.size() == 1 and forgiven[0] == GameState.Ending.TRUE_END,
		"a couple of honest false flags still allow the True ending")

	# The ramp never resets after an early night.
	GameState.reset()
	GameState.advance_shift()
	GameState.advance_shift()
	_expect(GameState.shift == 3, "shifts always move forward, even after incidents")

# --- False flags --------------------------------------------------------------

func _test_false_flags() -> void:
	print("\nFalse flags cost standing, not strikes")
	GameState.reset()
	GameState.set_player_name("Zahidul")

	GameState.record_false_flag()
	_expect(GameState.strikes_taken == 0, "a false flag never costs a strike")
	_expect(GameState.standing < 0, "but standing takes a real hit (%d)" % GameState.standing)
	_expect(not GameState.false_flags_warrant_warning(), "one is not worth mentioning")

	GameState.record_false_flag()
	GameState.record_false_flag()
	_expect(GameState.false_flags_warrant_warning(), "three earns a word from the Dean")

	var before := GameState.standing
	GameState.record_correct_flag()
	_expect(GameState.standing > before, "a correct flag nudges standing back up")

	# And the runner actually fires that warning once.
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var runner := ShiftRunner.new()
	runner.rulebook = _book
	add_child(runner)
	var warnings: Array = []
	var sent_home: Array = []
	var ended: Array = []
	runner.dean_warning.connect(func(lines: PackedStringArray) -> void: warnings.append(lines))
	runner.sent_home.connect(func(lines: PackedStringArray) -> void: sent_home.append(lines))
	runner.shift_ended.connect(func(reason: int) -> void: ended.append(reason))

	runner.start(4, 4242)
	var guard := 0
	while runner.current() != null and not runner.shift_over and guard < 40:
		runner.resolve(DecisionJudge.FLAG)   # flag absolutely everyone
		guard += 1
	_expect(GameState.false_flags >= 3, "flagging everyone racks up false flags (%d)" % GameState.false_flags)
	_expect(warnings.size() == 1, "the Dean warns about it exactly once")
	_expect(sent_home.size() == 1, "the next one after the warning sends the player home")
	_expect(ended.size() == 1 and ended[0] == ShiftRunner.EndReason.SENT_HOME,
		"and the shift ends for that reason, not an incident")
	_expect(GameState.strikes_taken == 0, "but flagging everyone never costs a strike")
	runner.queue_free()

# --- The Dean -----------------------------------------------------------------

func _test_dean_escalation() -> void:
	print("\nThe Dean escalates")
	var name := "Zahidul"
	for strike in range(1, 6):
		var lines := Dean.arrival_lines(strike, name)
		var joined := "\n".join(lines)
		if lines.is_empty():
			_failures += 1
			print("  FAIL  strike %d has no lines" % strike)
			continue
		if not joined.contains(name):
			_failures += 1
			print("  FAIL  strike %d never uses the player's name" % strike)
			continue
		print("  ok    strike %d (%s): \"%s\"" % [strike, Dean.demeanour(strike), lines[0]])

	_expect(Dean.demeanour(1) == "mildly irritated", "strike 1 is mildly irritated")
	_expect(Dean.demeanour(4) == "openly threatening", "strike 4 is openly threatening")
	_expect(Dean.demeanour(5) == "detached",
		"strike 5 is detached — more bothered by the paperwork than the incident")
	_expect("\n".join(Dean.arrival_lines(5, name)).to_lower().contains("form"),
		"and his last word on it is about a form")

	for which in [GameState.Ending.FIRED, GameState.Ending.STANDARD, GameState.Ending.TRUE_END]:
		_expect(Dean.ending_lines(which).size() > 0,
			"the %s ending has closing text" % GameState.ending_name(which))
