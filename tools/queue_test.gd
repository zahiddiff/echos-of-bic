extends SceneTree

## Tests the task pool, shift curve, wrongness authors and the queue generator.
## Run: godot --headless --path <project> --script res://tools/queue_test.gd

var _failures := 0
var _book: Rulebook

func _init() -> void:
	_book = Rulebook.new()
	_book.current_date = "2026-09-17"

	_test_task_pool()
	_test_schedule()
	_test_clean_requests()
	_test_wrongness()
	_test_queue_shape()
	_test_determinism()

	print("")
	if _failures == 0:
		print("QUEUE TEST PASSED")
	else:
		print("QUEUE TEST FAILED (%d problem(s))" % _failures)
	quit(1 if _failures > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

func _test_task_pool() -> void:
	print("Task pool")
	var tasks := TaskPool.all()
	_expect(tasks.size() == 20, "exactly 20 request types (got %d)" % tasks.size())

	var ids := {}
	for task in tasks:
		ids[task.id] = true
	_expect(ids.size() == tasks.size(), "every task id is unique")

	var categories := {}
	for task in tasks:
		categories[task.category] = true
	_expect(categories.size() == 5, "all five categories are represented (got %d)" % categories.size())

	var physical := TaskPool.physical_tasks().size()
	_expect(physical >= 4 and physical <= 10,
		"a workable mix of desk and physical tasks (%d physical, %d desk)"
			% [physical, TaskPool.desk_tasks().size()])
	_expect(TaskPool.by_id("visa_extension") != null, "tasks are findable by id")
	_expect(TaskPool.by_id("nonsense") == null, "an unknown id returns null")

	var stamped := 0
	for task in tasks:
		if task.needs_prior_stamp:
			stamped += 1
	_expect(stamped > 0 and stamped < tasks.size(),
		"some tasks need a prior stamp and some don't (%d of %d)" % [stamped, tasks.size()])

func _test_schedule() -> void:
	print("\nShift curve")
	var expected_visitors := {1: 8, 2: 8, 3: 9, 4: 9, 5: 10, 6: 10, 7: 11, 8: 11}
	var ok := true
	for shift: int in expected_visitors:
		if ShiftSchedule.visitors_for(shift) != expected_visitors[shift]:
			ok = false
			print("        shift %d gave %d visitors, expected %d"
				% [shift, ShiftSchedule.visitors_for(shift), expected_visitors[shift]])
	_expect(ok, "visitor counts match the design table")

	_expect(ShiftSchedule.threats_for(1) == 0,
		"shift 1 is the scripted onboarding shift with no threats")
	var threats_ok := ShiftSchedule.threats_for(2) == 1 \
		and ShiftSchedule.threats_for(4) == 2 \
		and ShiftSchedule.threats_for(6) == 3 \
		and ShiftSchedule.threats_for(8) == 4
	_expect(threats_ok, "threat counts ramp 1 / 2 / 3 / 4 across the bands")

	var total := ShiftSchedule.total_threats()
	_expect(total >= 18 and total <= 20,
		"about 20 threat encounters in a run (got %d)" % total)
	_expect(ShiftSchedule.difficulty_for(1) > ShiftSchedule.difficulty_for(8),
		"wrongness gets harder to spot as shifts go on")
	_expect(not ShiftSchedule.is_valid(0) and not ShiftSchedule.is_valid(9),
		"shifts outside 1-8 are rejected")

func _test_clean_requests() -> void:
	print("\nGenerated paperwork is clean by construction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var maker := RequestGenerator.new(_book, rng)

	var dirty := 0
	var offenders := ""
	for task in TaskPool.all():
		for attempt in 12:
			var request := maker.clean_request(task)
			var broken := _book.violations(request)
			if not broken.is_empty():
				dirty += 1
				if offenders.length() < 160:
					offenders += "\n        %s -> %s" % [task.id, broken[0]]
	_expect(dirty == 0,
		"240 generated requests across all 20 tasks break no rules%s" % offenders)

	var sample := maker.clean_request(TaskPool.by_id("visa_extension"))
	_expect(sample.requires_prior_stamp and sample.has_prior_stamp,
		"a task that needs a prior stamp is generated with one")
	_expect(sample.id_photo == sample.visitor_portrait,
		"a clean visitor's ID photo is the same image as their face")

func _test_wrongness() -> void:
	print("\nWrongness breaks exactly one thing")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var maker := RequestGenerator.new(_book, rng)
	var author := WrongnessAuthor.new(_book, rng)

	var identity_caught := 0
	var data_caught := 0
	for attempt in 40:
		var request := maker.clean_request(TaskPool.by_id("schedule_lookup"))
		author.apply(request, VisitorRequest.Wrongness.IDENTITY, 0.6)
		if not _book.passes(request):
			identity_caught += 1

		var other := maker.clean_request(TaskPool.by_id("schedule_lookup"))
		author.apply(other, VisitorRequest.Wrongness.DATA)
		if not _book.passes(other):
			data_caught += 1

	_expect(identity_caught == 40,
		"every Identity Wrongness is catchable by the rulebook (%d/40)" % identity_caught)
	_expect(data_caught == 40,
		"every Data Wrongness is catchable by the rulebook (%d/40)" % data_caught)

	# Physical wrongness needs a task that actually leaves the desk.
	var physical := maker.clean_request(TaskPool.by_id("transcript_print"))
	author.apply(physical, VisitorRequest.Wrongness.PHYSICAL)
	_expect(not _book.passes(physical),
		"Physical Wrongness on a print-room task shows up on the returned form")

	# On a desk-only task it has nowhere to happen, so it must not silently leave the visitor clean.
	var desk_only := maker.clean_request(TaskPool.by_id("room_lookup"))
	author.apply(desk_only, VisitorRequest.Wrongness.PHYSICAL)
	_expect(desk_only.wrongness == VisitorRequest.Wrongness.DATA,
		"Physical Wrongness on a desk-only task falls back to Data, not to clean")
	_expect(not _book.passes(desk_only), "and that visitor is still wrong")

	_expect(not WrongnessAuthor.is_rulebook_visible(VisitorRequest.Wrongness.REPETITION),
		"Repetition is not something the rules sheet can see")

func _test_queue_shape() -> void:
	print("\nQueue composition")
	for shift in range(1, 9):
		var generator := QueueGenerator.new(_book, 1000 + shift)
		var queue := generator.build_shift(shift)

		var expected := ShiftSchedule.visitors_for(shift)
		if queue.size() != expected:
			_failures += 1
			print("  FAIL  shift %d has %d visitors, expected %d" % [shift, queue.size(), expected])
			continue

		var threats := 0
		var wrong := 0
		var threat_slots: Array[int] = []
		for index in queue.size():
			if queue[index].is_threat:
				threats += 1
				threat_slots.append(index)
			if queue[index].wrongness != VisitorRequest.Wrongness.NONE:
				wrong += 1

		var want_threats := ShiftSchedule.threats_for(shift)
		if threats != want_threats:
			_failures += 1
			print("  FAIL  shift %d has %d threats, expected %d" % [shift, threats, want_threats])
		else:
			print("  ok    shift %d: %d visitors, %d threats at %s, %d carrying wrongness"
				% [shift, queue.size(), threats, str(threat_slots), wrong])

	print("")
	var onboarding := QueueGenerator.new(_book, 7).build_shift(1)
	var all_clean := true
	for request in onboarding:
		if request.wrongness != VisitorRequest.Wrongness.NONE or request.is_threat:
			all_clean = false
	_expect(all_clean, "nothing is wrong on the onboarding shift")

	# Threats should not bunch up at one end of the queue.
	var late := QueueGenerator.new(_book, 31337).build_shift(8)
	var slots: Array[int] = []
	for index in late.size():
		if late[index].is_threat:
			slots.append(index)
	var spread_ok := slots.size() < 2 or (slots[slots.size() - 1] - slots[0]) >= late.size() / 2
	_expect(spread_ok, "threats are spread across the shift, not clustered %s" % str(slots))

	# Repetition, when it fires, means one ID under two names.
	var seen_repetition := false
	for attempt in 30:
		var queue := QueueGenerator.new(_book, 500 + attempt).build_shift(6)
		var numbers := {}
		for request in queue:
			if numbers.has(request.id_number) and numbers[request.id_number] != request.id_name:
				seen_repetition = true
			numbers[request.id_number] = request.id_name
	_expect(seen_repetition,
		"Repetition Wrongness does occur: one ID number, two different names")

func _test_determinism() -> void:
	print("\nSeeded shifts are reproducible")
	var first := QueueGenerator.new(_book, 2024).build_shift(5)
	var second := QueueGenerator.new(_book, 2024).build_shift(5)
	var third := QueueGenerator.new(_book, 2025).build_shift(5)

	var same := first.size() == second.size()
	if same:
		for index in first.size():
			if first[index].describe() != second[index].describe() \
					or first[index].is_threat != second[index].is_threat:
				same = false
				break
	_expect(same, "the same seed rebuilds the same shift exactly")

	var differs := false
	for index in mini(first.size(), third.size()):
		if first[index].describe() != third[index].describe():
			differs = true
			break
	_expect(differs, "a different seed gives a different shift")
