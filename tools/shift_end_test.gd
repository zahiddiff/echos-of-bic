extends Node

## Tests the end of a night: the shift report appears, clocking out moves the run on, and the last shift ends the run on the ending screen.
## Run: godot --headless --path <project> res://tools/shift_end_test.tscn

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
	print("Shift end test")
	await _test_report_and_next_shift()
	await _test_final_shift_ends_run()
	await _test_portraits_render_on_demand()

	print("")
	if _failures == 0:
		print("SHIFT END TEST PASSED")
	else:
		print("SHIFT END TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _building(shift: int) -> BICBuilding:
	var building: BICBuilding = load(BUILDING).instantiate()
	building.shift = shift
	building.queue_seed = 5150
	building.visitors_enabled = false
	building.decision_pause = 0.0
	building.reload_on_continue = false
	add_child(building)
	building.dialogue.reading_speed = 600.0
	building.dialogue.silence_padding = 0.02
	await get_tree().process_frame
	return building

## Approve everyone until the night ends, however it ends.
func _work_the_queue(building: BICBuilding) -> void:
	var guard := 0
	while building.runner.current() != null and not building.runner.shift_over and guard < 200:
		building.runner.resolve(BICBuilding.Decision.APPROVE)
		guard += 1
		await get_tree().process_frame

func _wait_for_report(building: BICBuilding, seconds: float) -> bool:
	var waited := 0.0
	while not building.report.is_showing and waited < seconds:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return building.report.is_showing

func _test_report_and_next_shift() -> void:
	print("\n A shift ends with a report")
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var building := await _building(2)
	_expect(GameState.shift == 2, "the building's shift is the run's shift")
	_expect(not building.report.is_showing, "no report while the night is running")

	await _work_the_queue(building)
	_expect(building.runner.shift_over, "the night is over")
	_expect(await _wait_for_report(building, 40.0), "and the shift report comes up on its own")
	_expect(building.report.mode == "report", "it is the report, not the ending")
	var summary := building.report.summary
	_expect(int(summary["shift"]) == 2, "it names the shift")
	_expect(int(summary["seen"]) == building.runner.index, "counts the visitors seen")
	_expect(int(summary["total"]) == building.runner.queue.size(), "out of the whole queue")
	_expect(int(summary["strikes_left"]) == GameState.strikes_remaining(), "shows the strikes left")
	_expect(str(summary["clock_out"]).length() == 5, "with a clock-out time (%s)" % summary["clock_out"])
	_expect(not building.status_bar.visible, "the status bar steps aside for it")

	building._on_report_continue()
	_expect(GameState.shift == 3, "clocking out moves the run to the next shift")
	building.queue_free()
	await get_tree().process_frame

func _test_final_shift_ends_run() -> void:
	print("\n The last shift ends the run")
	GameState.reset()
	GameState.set_player_name("Zahidul")
	var building := await _building(8)
	await _work_the_queue(building)
	_expect(await _wait_for_report(building, 60.0), "shift 8 gets its report")
	_expect(bool(building.report.summary["run_over"]), "which knows it is the last one")
	building._on_report_continue()
	_expect(GameState.run_over, "continuing ends the run")
	_expect(building.report.mode == "ending", "and shows the ending (%s)" % GameState.ending_name(GameState.ending))
	building.queue_free()
	await get_tree().process_frame
	GameState.reset()

func _test_portraits_render_on_demand() -> void:
	print("\n ID photos")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var request := RequestGenerator.new(Rulebook.new(), rng).clean_request(TaskPool.by_id("schedule_lookup"))
	_expect(request.visitor_face != null, "a generated visitor has a face")
	var start := Time.get_ticks_msec()
	var photo := request.visitor_portrait
	var took := Time.get_ticks_msec() - start
	_expect(photo != null and photo.get_width() == 240, "the photo renders when first looked at")
	_expect(request.visitor_portrait == photo, "and only once")
	_expect(request.id_photo == photo, "a clean ID shows the same photo")
	print("        (%d ms to render one)" % took)
	var again := PortraitFactory.render(PortraitFactory.traits_for(12345), Vector2i(240, 300))
	var same := PortraitFactory.render(PortraitFactory.traits_for(12345), Vector2i(240, 300))
	_expect(again.get_image().get_data() == same.get_image().get_data(), "the same face renders identically")
