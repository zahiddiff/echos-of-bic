extends Node

## Tests the scripted first shift.
## Run: godot --headless --path <project> res://tools/onboarding_test.tscn

var _failures := 0
var _book: Rulebook

func _ready() -> void:
	_book = Rulebook.new()
	_book.current_date = "2026-09-17"

	_test_lesson_plan()
	_test_queue_is_harmless()
	_test_rules_arrive_one_at_a_time()
	_test_beats_in_order()
	_test_shift_two_is_not_suppressed()

	print("")
	if _failures == 0:
		print("ONBOARDING TEST PASSED")
	else:
		print("ONBOARDING TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

# --- The lesson plan ----------------------------------------------------------

func _test_lesson_plan() -> void:
	print("Lesson plan")
	_expect(Onboarding.visitor_count() == ShiftSchedule.visitors_for(1),
		"shift one has the %d visitors the curve calls for" % ShiftSchedule.visitors_for(1))
	_expect(Onboarding.all_rules_taught(),
		"all six rules are taught by the end of the night")

	# Never more than one new rule per visitor.
	var crowded := 0
	var taught: Array[int] = []
	for number in range(1, Onboarding.visitor_count() + 1):
		var before := Onboarding.rules_known_at(number - 1).size()
		var after := Onboarding.rules_known_at(number).size()
		if after - before > 1:
			crowded += 1
		if after > before:
			taught.append(Onboarding.rule_taught_by(number))
	_expect(crowded == 0, "no visitor ever introduces more than one new rule")
	_expect(taught.size() == 6, "six teaching visitors (%d)" % taught.size())

	var unique := {}
	for rule in taught:
		unique[rule] = true
	_expect(unique.size() == 6, "and no rule is taught twice")

	_expect(Onboarding.rule_taught_by(4) == -1,
		"visitor 4 teaches the walk to the print room, not a rule")
	var walk_task := TaskPool.by_id(Onboarding.LESSONS[3]["task"])
	_expect(walk_task != null and walk_task.physical,
		"and their task really does send the player away from the desk")
	_expect(Onboarding.rule_taught_by(Onboarding.FLAG_TRAINING_VISITOR) == -1,
		"the flag demonstration does not also try to teach a rule")

# --- Nothing is wrong on shift one --------------------------------------------

func _test_queue_is_harmless() -> void:
	print("\nNothing on shift one is wrong")
	var queue := Onboarding.build(_book)
	_expect(queue.size() == 8, "eight visitors (%d)" % queue.size())

	var full_book := Rulebook.new()
	full_book.current_date = _book.current_date

	var problems := 0
	var threats := 0
	var voiceless := 0
	for request in queue:
		if request.wrongness != VisitorRequest.Wrongness.NONE:
			problems += 1
		if request.is_threat:
			threats += 1
		if not full_book.passes(request):
			problems += 1
		if request.dialogue == null or request.dialogue.opening == null:
			voiceless += 1

	_expect(threats == 0, "no threats at all")
	_expect(problems == 0, "nobody breaks a rule, even one that hasn't been taught yet")
	_expect(voiceless == 0, "every teaching visitor speaks")

	# Reproducible, so the scripted shift is the same for every player.
	var again := Onboarding.build(_book)
	var identical := true
	for i in queue.size():
		if queue[i].describe() != again[i].describe():
			identical = false
	_expect(identical, "shift one is the same every time — it is written, not rolled")

# --- One rule at a time -------------------------------------------------------

func _test_rules_arrive_one_at_a_time() -> void:
	print("\nRules arrive one at a time")
	_expect(Onboarding.rules_known_at(1).size() == 1,
		"visitor 1 arrives with exactly one rule explained")
	_expect(Onboarding.rules_known_at(1)[0] == Rulebook.Rule.NAME_MATCH,
		"and it is the name match")
	_expect(Onboarding.rules_known_at(3).size() == 3, "three rules known by visitor 3")
	_expect(Onboarding.rules_known_at(4).size() == 3,
		"visitor 4 adds none — the lesson is leaving the desk")
	_expect(Onboarding.rules_known_at(8).size() == 6, "all six by the last visitor")

	# An untaught rule must not be able to fail the player.
	var partial := Rulebook.new()
	partial.current_date = _book.current_date
	partial.enabled_rules = Onboarding.rules_known_at(1)
	var request := Onboarding.build(_book)[0]
	request.college_code = "ZZZ"
	request.issue_date = "1999-01-01"
	_expect(partial.passes(request),
		"a rule the player has not been taught cannot mark them wrong")
	_expect(partial.check_all(request).size() == 1, "only the taught rule is even checked")

# --- Beats fire in order ---------------------------------------------------

func _test_beats_in_order() -> void:
	print("\nThe night runs in order")
	GameState.reset()
	GameState.set_player_name("Zahidul")

	var runner := ShiftRunner.new()
	runner.rulebook = Rulebook.new()
	runner.rulebook.current_date = _book.current_date
	add_child(runner)

	var beats: Array[String] = []          # first line of each beat, for ordering
	var spoken: Array[String] = []          # everything Rahat actually says
	var rules_announced: Array[String] = []
	runner.mentor_line.connect(
		func(lines: PackedStringArray) -> void:
			beats.append(lines[0])
			for line in lines:
				spoken.append(line))
	runner.rule_taught.connect(
		func(_rule: int, title: String) -> void: rules_announced.append(title))

	runner.start(1, 0)
	_expect(runner.is_onboarding, "shift one is flagged as onboarding")
	_expect(beats.size() >= 2, "Rahat introduces himself before the first visitor")
	_expect(beats[0].contains("Rahat"), "the cold open is him, not the Dean (\"%s\")" % beats[0])

	var guard := 0
	while runner.current() != null and not runner.shift_over and guard < 20:
		runner.resolve(DecisionJudge.APPROVE)
		guard += 1

	_expect(runner.shift_over, "the shift finishes")
	_expect(GameState.strikes_taken == 0, "and cannot cost a strike")
	_expect(rules_announced.size() == 6,
		"all six rules were announced as they were taught (%d)" % rules_announced.size())

	var all_beats := " ".join(spoken)
	_expect(all_beats.contains("radio"), "the flag demonstration happened")
	_expect(all_beats.contains("Prof. Joo"),
		"the strike system is planted verbally, with no meter on screen")
	_expect(spoken[spoken.size() - 1].contains("tomorrow"),
		"and the night closes on Rahat signing off")
	_expect(all_beats.contains("odd"),
		"ending on one small unresolved detail, nothing overtly wrong")

	print("")
	for rule in rules_announced:
		print("        taught: %s" % rule)

	runner.queue_free()

# --- And shift two is the real job -------------------------------------------

func _test_shift_two_is_not_suppressed() -> void:
	print("\nShift two is the real job")
	GameState.reset()
	GameState.set_player_name("Zahidul")

	var runner := ShiftRunner.new()
	runner.rulebook = Rulebook.new()
	runner.rulebook.current_date = _book.current_date
	runner.generate_portraits = false
	add_child(runner)

	runner.start(2, 777)
	_expect(not runner.is_onboarding, "shift two is not onboarding")
	_expect(runner.rulebook.enabled_rules.is_empty(),
		"every rule is live again — nothing stays suppressed")

	var threats := 0
	for request in runner.queue:
		if request.is_threat:
			threats += 1
	_expect(threats == ShiftSchedule.threats_for(2),
		"and threats are back (%d)" % threats)

	runner.queue_free()
