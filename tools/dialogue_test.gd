extends Node

## Tests the subtitled dialogue and the optional follow-ups.
## Run: godot --headless --path <project> res://tools/dialogue_test.tscn

var _failures := 0
var _view: DialogueView

func _ready() -> void:
	_run()

func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)

func _ok(message: String) -> void:
	print("  ok    %s" % message)

func _expect(condition: bool, message: String) -> void:
	if condition:
		_ok(message)
	else:
		_fail(message)

func _line(text: String, delivery: DialogueLine.Delivery = DialogueLine.Delivery.NORMAL,
		lead_in: float = 0.0) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker = "Visitor"
	line.text = text
	line.delivery = delivery
	line.lead_in = lead_in
	line.hold = 0.15   # keep the test quick
	return line

func _run() -> void:
	print("Dialogue test")

	print("\n Line timing")
	var quick := DialogueLine.new()
	quick.text = "Short."
	_expect(quick.display_seconds() >= 1.4, "very short lines still hold a readable minimum")
	var long_line := DialogueLine.new()
	long_line.text = "x".repeat(400)
	_expect(long_line.display_seconds() <= 7.0, "very long lines are capped")
	var fixed := DialogueLine.new()
	fixed.text = "anything"
	fixed.hold = 3.0
	_expect(is_equal_approx(fixed.display_seconds(), 3.0), "an explicit hold wins")
	_expect(not quick.is_tell(), "a normal delivery is not a tell")
	var hesitant := _line("…Yes.", DialogueLine.Delivery.HESITANT, 0.2)
	_expect(hesitant.is_tell(), "a hesitant delivery is a tell")

	print("\n Follow-ups are optional and single-use")
	var talk := VisitorDialogue.new()
	talk.opening = _line("Hi — I have a request.")
	talk.closing = _line("Thank you.")
	talk.follow_ups = [
		VisitorDialogue.FollowUp.make("Which scholarship?", _line("The faculty one.")),
		VisitorDialogue.FollowUp.make("Is this your own schedule?",
			_line("Yeah. Yeah, mine.", DialogueLine.Delivery.TOO_FAST)),
	]
	_expect(talk.follow_ups.size() <= 2, "never more than two follow-ups")
	_expect(talk.has_questions_left(), "both start unasked")

	_view = load("res://scenes/desk/dialogue_view.tscn").instantiate()
	add_child(_view)
	await get_tree().process_frame

	var started: Array[String] = []
	var asked: Array[String] = []
	_view.line_started.connect(func(line: DialogueLine) -> void: started.append(line.text))
	_view.follow_up_asked.connect(
		func(f: VisitorDialogue.FollowUp) -> void: asked.append(f.question))

	await _view.begin(talk)
	_expect(started.size() == 1 and started[0] == talk.opening.text,
		"the opening plays first")
	_expect(_view.visible, "the subtitle layer is up")
	_expect(_view.questions.visible, "the follow-up questions are offered")
	# Two questions plus "Say nothing more".
	_expect(_view.questions.get_child_count() == 3,
		"both questions plus a way to decline (got %d)" % _view.questions.get_child_count())

	await _view.ask(talk.follow_ups[0])
	_expect(asked.size() == 1, "asking reports it")
	_expect(talk.follow_ups[0].asked, "the question is marked asked")
	_expect(talk.available_follow_ups().size() == 1, "only the other one is left")
	_expect(_view.questions.get_child_count() == 2,
		"the asked question is no longer offered")

	await _view.ask(talk.follow_ups[0])
	_expect(asked.size() == 1, "asking the same question twice does nothing")

	print("\n Silence is played, not captioned")
	var quiet_talk := VisitorDialogue.new()
	quiet_talk.opening = _line("Could you look up a schedule?")
	quiet_talk.closing = _line("It's fine. I'll come back.")
	var silent := _line("", DialogueLine.Delivery.GOES_QUIET, 0.05)
	quiet_talk.follow_ups = [
		VisitorDialogue.FollowUp.make("Which department are you in?", silent),
	]
	_view.silence_padding = 0.1
	await _view.begin(quiet_talk)
	var subtitle_during_silence := [""]
	_view.line_started.connect(
		func(line: DialogueLine) -> void:
			if line == silent:
				subtitle_during_silence[0] = _view.subtitle.text,
		CONNECT_ONE_SHOT)
	await _view.ask(quiet_talk.follow_ups[0])
	_expect(subtitle_during_silence[0] == "",
		"going quiet shows no subtitle at all (got \"%s\")" % subtitle_during_silence[0])

	print("\n Wrapping up")
	var finished := [false]
	_view.exhausted.connect(func() -> void: finished[0] = true)
	await _view.wrap_up()
	await get_tree().process_frame
	_expect(finished[0], "wrap_up plays the closing and reports the visitor is done")
	_expect(not _view.visible, "the subtitle layer goes away")

	print("\n Generated visitors carry dialogue")
	var book := Rulebook.new()
	book.current_date = "2026-09-17"
	var queue := QueueGenerator.new(book, 8080).build_shift(6)

	var missing := 0
	var wrong_count := 0
	var threats := 0
	var threats_with_tells := 0
	var innocents := 0
	var innocents_with_tells := 0

	for visitor in queue:
		if visitor.dialogue == null or visitor.dialogue.opening == null \
				or visitor.dialogue.closing == null:
			missing += 1
			continue
		var question_count := visitor.dialogue.follow_ups.size()
		if question_count < 1 or question_count > 2:
			wrong_count += 1

		var has_tell := false
		for follow_up in visitor.dialogue.follow_ups:
			if follow_up.answer and follow_up.answer.is_tell():
				has_tell = true

		if visitor.is_threat:
			threats += 1
			if has_tell:
				threats_with_tells += 1
		else:
			innocents += 1
			if has_tell:
				innocents_with_tells += 1

	_expect(missing == 0, "every generated visitor has an opening and a closing")
	_expect(wrong_count == 0, "every generated visitor has one or two follow-ups")
	_expect(threats > 0, "the shift contains threats to check (%d)" % threats)
	_expect(threats_with_tells > 0,
		"threats show behavioural tells (%d of %d)" % [threats_with_tells, threats])
	# If only threats were ever nervous, one follow-up would identify every threat with certainty and the whole Approve/Reject/Flag tension collapses.
	_expect(innocents_with_tells > 0,
		"some innocent visitors are nervous too (%d of %d)" % [innocents_with_tells, innocents])
	_expect(innocents_with_tells < innocents,
		"but most innocent visitors answer plainly")

	print("")
	if _failures == 0:
		print("DIALOGUE TEST PASSED")
	else:
		print("DIALOGUE TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
