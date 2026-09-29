extends Node

## Headless functional test for the gray-boxed building.
## Run: godot --headless --path <project> res://tools/building_test.tscn

const BUILDING := "res://scenes/building/bic_building.tscn"

## Every coordinate in this test comes from BuildingLayout, the same source the generator builds from — so resizing a room never silently breaks the test.
const L := preload("res://code/world/building_layout.gd")

var _failures := 0
var _building: Node3D
var _player: PlayerController
var _hud: InteractHUD

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

func _settle(frames: int = 4) -> void:
	for i in frames:
		await get_tree().physics_frame

func _aim_at(from: Vector3, target: Vector3) -> void:
	_player.global_position = from
	_player.rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	var eye := from + Vector3(0, 1.6, 0)
	var flat := Vector2(target.x - eye.x, target.z - eye.z).length()
	_player.rotation.y = atan2(eye.x - target.x, eye.z - target.z)
	_player.head.rotation.x = atan2(target.y - eye.y, flat)
	# The InteractRay needs a few physics steps to re-resolve after a teleport.
	await _settle(4)

## Does a standing player capsule fit here without hitting world geometry?
func _blockers_at(position: Vector3) -> Array[String]:
	await get_tree().physics_frame
	var space := _player.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.78
	params.shape = capsule
	params.transform = Transform3D(Basis(), position + Vector3(0, 0.9, 0))
	params.collision_mask = 1
	params.collide_with_areas = false
	var names: Array[String] = []
	for hit in space.intersect_shape(params, 8):
		names.append(str(hit["collider"].name))
	return names

func _run() -> void:
	print("Building test")
	_building = load(BUILDING).instantiate()
	# People walking through the front doors would open them mid-check. character_test covers the visitors; this test covers the building.
	_building.visitors_enabled = false
	_building.decision_pause = 0.0
	add_child(_building)
	await _settle()

	_player = _building.get_node("Player")
	_hud = _building.get_node("InteractHUD")

	var print_door: Door = _building.get_node("Doors/DoorPrintRoom")
	var storage_door: Door = _building.get_node("Doors/DoorStorage")
	var meeting_door: Door = _building.get_node("Doors/DoorMeetingRoom")
	var entrance: SlidingEntrance = _building.get_node("Doors/Entrance")

	# --- Locked-door policy -----------------------------------------------
	print("\n Locked-door policy")
	_expect(not print_door.locked, "print room door is UNLOCKED (required for physical tasks)")
	_expect(storage_door.locked, "storage door is LOCKED by default")
	_expect(meeting_door.locked, "meeting room door is LOCKED by default")
	_expect(storage_door.get_prompt() == "Locked",
		"locked door prompt reads \"Locked\" (got \"%s\")" % storage_door.get_prompt())

	# --- A locked door refuses --------------------------------------------
	print("\n Storage door (locked)")
	var door_x := L.doorway_centre_x()
	await _aim_at(Vector3(door_x, 0.02, L.Z_STORAGE_MAIN + 1.2), Vector3(door_x, 1.1, L.Z_STORAGE_MAIN))
	_expect(_player._current_focus == storage_door, "raycast focuses the storage door")
	_expect(_hud.prompt_label.text == "Locked",
		"HUD shows \"Locked\" (got \"%s\")" % _hud.prompt_label.text)
	var refused := [false]
	storage_door.refused.connect(func(_p: Node) -> void: refused[0] = true)
	_player._try_interact()
	await _settle(2)
	_expect(refused[0], "E on the locked door fires `refused`")
	_expect(not storage_door.is_open, "locked door stays shut")
	_expect((await _blockers_at(Vector3(door_x, 0, L.Z_STORAGE_MAIN))).size() > 0,
		"storage doorway is physically blocked")

	# --- An unlocked door opens and closes ---------------------------------
	print("\n Print room door (unlocked)")
	await _aim_at(Vector3(door_x, 0.02, L.Z_MAIN_PRINT - 0.9), Vector3(door_x, 1.1, L.Z_MAIN_PRINT))
	_expect(_player._current_focus == print_door, "raycast focuses the print room door")
	_expect(_hud.prompt_label.text == "Open the print room door",
		"HUD shows the open prompt (got \"%s\")" % _hud.prompt_label.text)
	_player._try_interact()
	await get_tree().create_timer(print_door.swing_time + 0.2).timeout
	_expect(print_door.is_open, "E opens the print room door")
	_expect(_hud.prompt_label.text == "Close the print room door",
		"prompt flips to close (got \"%s\")" % _hud.prompt_label.text)
	_expect((await _blockers_at(Vector3(door_x, 0, L.Z_MAIN_PRINT))).is_empty(),
		"print room doorway is clear once open")

	# The leaf swung into the print room, so look at it from in there.
	var leaf: Node3D = print_door.get_node("Leaf")
	await _aim_at(Vector3(L.DOORWAY_X1 - 0.2, 0.02, L.Z_MAIN_PRINT + 1.2), leaf.global_position)
	_expect(_player._current_focus == print_door, "open leaf is still focusable")
	_player._try_interact()
	await get_tree().create_timer(print_door.swing_time + 0.2).timeout
	_expect(not print_door.is_open, "E again closes it")

	# --- Automatic entrance ------------------------------------------------
	print("\n Entrance (automatic)")
	# Earlier steps parked the player inside the entrance trigger, so let the auto-close finish sliding before asserting anything about the panels.
	var doors_at := L.entrance_centre()
	var away := Vector3(0.0, 0.02, L.COUNTER_Z)
	_player.global_position = away
	await _settle(4)
	await get_tree().create_timer(entrance.close_delay + entrance.slide_time + 0.4).timeout
	_expect(not entrance.is_open, "entrance starts closed")
	_expect((await _blockers_at(doors_at)).size() > 0,
		"closed entrance blocks the opening")

	_player.global_position = Vector3(L.X_MAX - 0.8, 0.02, doors_at.z)
	_player.velocity = Vector3.ZERO
	await _settle(4)
	_expect(entrance.is_open, "walking up to the entrance opens it")
	await get_tree().create_timer(entrance.slide_time + 0.2).timeout
	_expect((await _blockers_at(doors_at)).is_empty(),
		"open entrance is walkable")

	_player.global_position = away
	await _settle(4)
	await get_tree().create_timer(entrance.close_delay + entrance.slide_time + 0.4).timeout
	_expect(not entrance.is_open, "entrance auto-closes after the player leaves")
	_expect((await _blockers_at(doors_at)).size() > 0,
		"closed again, the opening is blocked")

	# --- The desk station (Weeks 3-5) --------------------------------------
	print("\n Desk station")
	var desk: DeskStation = _building.get_node("Props/PlayerDesk/DeskStation")
	var viewer: DocumentViewer = _building.get_node("DocumentViewer")

	var station := L.DESK_STATION
	await _aim_at(Vector3(station.x, 0.02, L.SEAT.z), Vector3(station.x, station.y + 0.1, station.z))
	_expect(_player._current_focus == desk, "the papers on the counter are focusable")
	_expect(_hud.prompt_label.text == "Work the desk",
		"HUD offers the desk (got \"%s\")" % _hud.prompt_label.text)
	_expect(not viewer.visible, "the viewer is closed while standing")

	var standing_at := _player.global_position
	_player._try_interact()
	desk.settle()
	await _settle(2)
	_expect(desk.is_seated, "E sits the player down at the desk")
	_expect(not _player.is_physics_processing(), "movement is disabled while seated")
	_expect(viewer.visible, "the current visitor's paperwork is on screen")

	var shown: VisitorRequest = _building.current_request()
	_expect(shown != null, "there is a visitor to serve")
	if shown:
		var form_name: Label = viewer.get_node("Surface/RequestForm/Sheet/Rows/RowName/Value")
		_expect(form_name.text == shown.form_name,
			"the form shows this visitor (\"%s\")" % form_name.text)

	# --- Approve / Reject / Flag are objects on the counter ----------------
	print("\n Desk actions")
	var stamp: StampAction = _building.get_node("Props/PlayerDesk/ApprovalStamp")
	var slip: RejectionSlip = _building.get_node("Props/PlayerDesk/RejectionSlip")
	var radio: DeskRadio = _building.get_node("Props/PlayerDesk/DeskRadio")

	var calls: Array = []
	_building.decision_made.connect(
		func(req: VisitorRequest, decision: int) -> void: calls.append([req, decision]))

	_expect(stamp.current_document != null, "sitting down loads the papers into the stamp")
	_expect(radio.current_document != null, "and into the radio")

	var served: VisitorRequest = _building.current_request()
	stamp.interact(_player)
	await _settle(2)
	_expect(calls.size() == 1, "stamping reports one decision (got %d)" % calls.size())
	if calls.size() == 1:
		_expect(calls[0][0] == served, "the decision names the visitor who was served")
		_expect(calls[0][1] == 0, "and records it as APPROVE")
	_expect(_building.current_request() != served, "the next visitor comes up")
	_expect(GameState.strikes_taken == 0, "no strike lands at the moment of the call")

	var second: VisitorRequest = _building.current_request()
	slip.interact(_player)
	await _settle(2)
	_expect(calls.size() == 2 and calls[1][1] == 1, "the rejection slip records REJECT")
	_expect(calls[1][0] == second, "for the second visitor")

	# The radio deliberately costs shift time, so it resolves on a timer.
	radio.call_seconds = 0.4
	radio.call_timer.wait_time = 0.4
	var third: VisitorRequest = _building.current_request()
	radio.interact(_player)
	_expect(radio.is_calling, "the radio starts a call rather than resolving instantly")
	_expect(calls.size() == 2, "and nothing is decided while it is still calling")
	await get_tree().create_timer(0.8).timeout
	_expect(not radio.is_calling, "the call finishes")
	_expect(calls.size() == 3 and calls[2][1] == 2, "and records FLAG")
	_expect(calls[2][0] == third, "for the visitor who was at the desk")

	# --- Records terminal ---------------------------------------------------
	print("\n Records terminal")
	var records: RecordsComputer = _building.get_node("Props/PlayerDesk/RecordsComputer")
	var screen: TerminalScreen = _building.get_node("TerminalScreen")

	_expect(not screen.visible, "the terminal screen starts dark")
	records.interact(_player)
	await _settle(2)
	_expect(records.is_open and screen.visible, "using the terminal brings it up")

	var on_file: VisitorRequest = _building.current_request()
	_expect(records.has_record(on_file.id_number),
		"the visitor at the desk has a record (%s)" % on_file.id_number)
	var printed := records.lookup(on_file.id_number)
	var joined := "\n".join(printed)
	_expect(joined.contains(on_file.id_name.to_upper()),
		"the record prints their name")
	_expect(joined.contains(on_file.college_code.to_upper()),
		"and their college code")

	var missing := records.lookup("BIC-99-000000")
	_expect("\n".join(missing).contains("NO MATCHING RECORD"),
		"an unknown number reports no record rather than inventing one")
	_expect(not records.has_record("BIC-99-000000"), "and has_record agrees")

	screen.dismiss()
	await _settle(2)
	_expect(not screen.visible and not records.is_open, "Esc looks away from the terminal")

	var at_the_counter: VisitorRequest = _building.current_request()
	desk.stand()
	desk.settle()
	await _settle(4)
	_expect(not desk.is_seated, "stand() gets the player back up")
	_expect(_player.is_physics_processing(), "movement is restored")
	_expect(not viewer.visible, "the paperwork goes away with them")
	_expect(_player.global_position.distance_to(standing_at) < 0.15,
		"the player is returned to where they were standing")
	_expect(_building.current_request() == at_the_counter,
		"stepping away does NOT skip them — they are still there when you get back")

	# --- Standing room -----------------------------------------------------
	print("\n Space check")
	var walkable := L.walkable_points()
	for label: String in walkable:
		var blockers := await _blockers_at(walkable[label])
		if blockers.is_empty():
			_ok("standing room: %s" % label)
		else:
			_fail("blocked: %s -> %s" % [label, ", ".join(blockers)])

	# --- The meeting room is a hard dead end -------------------------------
	print("\n Dead end")
	var far_wall := L.Z_MIN - L.WALL_T * 0.5
	_expect((await _blockers_at(Vector3(0.0, 0, far_wall))).size() > 0,
		"the meeting room's far wall is solid — no path beyond it")
	_expect((await _blockers_at(Vector3(door_x, 0, far_wall))).size() > 0,
		"no opening at the east end of the far wall either")

	# --- Proportions ---------------------------------------------------------
	print("\n Proportions")
	var depths := L.room_depths()
	_expect(L.width() <= 10.0, "the building is office-sized, not a warehouse (%.1f m wide)" % L.width())
	_expect(depths["main"] >= 5.0 and depths["main"] <= 6.5,
		"the main floor is %.1f m deep" % depths["main"])
	for room: String in depths:
		_expect(depths[room] >= 2.8, "%s is at least 2.8 m deep (%.1f)" % [room, depths[room]])
	_expect(L.DOORWAY_WIDTH >= 0.9 and L.DOORWAY_WIDTH <= 1.2,
		"internal doors are real single-door width (%.1f m)" % L.DOORWAY_WIDTH)
	var pocket := L.Z_MAIN_PRINT - L.WALL_T * 0.5 - L.counter_back_z()
	_expect(pocket >= 1.0, "there is room to stand behind the counter (%.2f m)" % pocket)

	print("")
	if _failures == 0:
		print("BUILDING TEST PASSED")
	else:
		print("BUILDING TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
