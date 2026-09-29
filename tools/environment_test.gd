extends Node

## Tests the environmental storytelling, the shift lighting ramp and the audio cue registry.
## Run: godot --headless --path <project> res://tools/environment_test.tscn

const BUILDING := "res://scenes/building/bic_building.tscn"

var _failures := 0
var _building: Node3D

func _ready() -> void:
	_run()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

func _run() -> void:
	print("Environment test")
	GameState.reset()
	GameState.set_player_name("Zahidul")

	_building = load(BUILDING).instantiate()
	_building.shift = 1
	add_child(_building)
	await get_tree().process_frame
	await get_tree().process_frame

	_test_props_exist()
	_test_nothing_before_it_is_earned()
	_test_flyer_needs_a_stalker()
	_test_rahat_leaves()
	_test_lighting_ramp()
	_test_audio_registry()

	print("")
	if _failures == 0:
		print("ENVIRONMENT TEST PASSED")
	else:
		print("ENVIRONMENT TEST FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _node(path: String) -> Node:
	return _building.get_node_or_null(NodePath(path))

func _visible(path: String) -> bool:
	var node := _node(path)
	return node is Node3D and (node as Node3D).visible

# --- The props are actually in the scene --------------------------------------

func _test_props_exist() -> void:
	print("\n The props exist")
	for path in ["Props/Story/MissingPersonFlyer", "Props/Story/SecurityMemo",
			"Props/Story/NewsClipping", "Props/Story/Bulletin",
			"Props/OtherDesk/RahatThings"]:
		_expect(_node(path) != null, "%s is in the building" % path.get_file())

# --- Nothing appears on a schedule --------------------------------------------

func _test_nothing_before_it_is_earned() -> void:
	print("\n Shift one, nothing has happened yet")
	GameState.reset()
	GameState.shift = 1
	_building.story.refresh()

	_expect(not _visible("Props/Story/MissingPersonFlyer"),
		"no missing-person flyer before anything has gone wrong")
	_expect(not _visible("Props/Story/SecurityMemo"),
		"no security memo before there is an incident to be memo'd about")
	_expect(not _visible("Props/Story/NewsClipping"),
		"no clipping on the board yet")
	_expect(_visible("Props/OtherDesk/RahatThings"),
		"Rahat's things are at his desk")

# --- The flyer is earned by a specific kind of failure ------------------------

func _test_flyer_needs_a_stalker() -> void:
	print("\n The flyer means something")
	GameState.reset()
	GameState.record_incident(ThreatType.Kind.THIEF)
	_building.story.refresh()
	_expect(not _visible("Props/Story/MissingPersonFlyer"),
		"a thief getting past the desk does NOT put up a missing-person flyer")
	_expect(_visible("Props/Story/SecurityMemo"),
		"but any incident does produce a memo about security awareness")

	var appeared: Array[String] = []
	_building.story.beat_appeared.connect(func(id: String, _n: String) -> void: appeared.append(id))

	GameState.record_incident(ThreatType.Kind.STALKER)
	_building.story.refresh()
	_expect(_visible("Props/Story/MissingPersonFlyer"),
		"a stalker getting past the desk does")
	_expect(appeared.has("missing_person_flyer"),
		"and the building reports it once, quietly")

	# It does not come back down.
	_building.story.refresh()
	_expect(appeared.size() == 1, "it is reported once, not every refresh")

# --- Rahat stops being there --------------------------------------------------

func _test_rahat_leaves() -> void:
	print("\n Rahat's desk")
	GameState.reset()
	for shift in [1, 3, 5]:
		GameState.shift = shift
		_building.story.refresh()
		_expect(_visible("Props/OtherDesk/RahatThings"),
			"shift %d — his things are still there" % shift)

	var removed: Array[String] = []
	_building.story.beat_removed.connect(func(id: String, _n: String) -> void: removed.append(id))

	GameState.shift = 6
	_building.story.refresh()
	_expect(not _visible("Props/OtherDesk/RahatThings"),
		"shift 6 — they are simply gone")
	_expect(removed.has("rahat_absent"), "and nothing in the game says a word about it")
	_expect(_node("Props/OtherDesk/Desk") != null,
		"the desk itself is still there, which is what makes it land")

# --- Lighting drains rather than darkens --------------------------------------

func _test_lighting_ramp() -> void:
	print("\n The building empties")
	var world_env := _node("WorldEnvironment") as WorldEnvironment
	_expect(world_env != null and world_env.environment != null, "the building has an environment")
	if world_env == null:
		return

	var lit_early := _lit_count(1)
	var lit_late := _lit_count(8)
	_expect(lit_early > lit_late,
		"fewer fixtures are on by shift 8 (%d -> %d)" % [lit_early, lit_late])
	_expect(lit_late > 0, "but the building is never dark (%d still lit)" % lit_late)
	_expect(float(lit_late) / float(lit_early) > 0.5,
		"and it drains rather than plunging — still %d%% lit"
			% int(100.0 * lit_late / lit_early))

	_building.lighting.apply(_building, 1)
	var early_ambient: float = world_env.environment.ambient_light_energy
	_building.lighting.apply(_building, 8)
	var late_ambient: float = world_env.environment.ambient_light_energy
	_expect(late_ambient < early_ambient,
		"ambient fill drops (%.2f -> %.2f)" % [early_ambient, late_ambient])
	_expect(late_ambient > 0.15, "but never to nothing — this is not horror lighting")

	_building.lighting.apply(_building, 1)

func _lit_count(shift: int) -> int:
	_building.lighting.apply(_building, shift)
	var lights := _building.get_node("Lights")
	return _count_visible_lights(lights)

func _count_visible_lights(node: Node) -> int:
	var total := 0
	if node is OmniLight3D and (node as OmniLight3D).visible:
		total += 1
	for child in node.get_children():
		total += _count_visible_lights(child)
	return total

# --- Audio: filled, looping where it should, and actually wired ---------------

func _test_audio_registry() -> void:
	print("\n Audio")
	var cues: AudioCues = load("res://assets/audio/bic_audio_cues.tres")
	_expect(cues != null, "the cue sheet loads")
	if cues == null:
		return

	var gaps := cues.missing()
	_expect(gaps.is_empty(), "all 16 cues have a sound behind them (missing: %s)" % str(gaps))

	for bed in ["room_tone", "room_tone_late", "fluorescent_buzz", "radio_static"]:
		var stream := cues.get(bed) as AudioStreamWAV
		_expect(stream != null and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED,
			"%s loops seamlessly" % bed)
	for sting in ["entrance_chime", "stamp", "door_locked", "terminal_key"]:
		var stream := cues.get(sting) as AudioStreamWAV
		_expect(stream != null and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"%s plays once" % sting)

	var chime := cues.entrance_chime
	_expect(chime.get_length() > 0.8 and chime.get_length() < 3.0,
		"the chime is short and ordinary (%.1fs)" % chime.get_length())
	_expect(cues.ambience_for(1) == cues.room_tone and cues.ambience_for(7) == cues.room_tone_late,
		"late shifts get the emptier room tone — no distant voices")

	print("\n The building is wired")
	var b := _building
	_expect(b.stamp.stamp_sound == cues.stamp, "the stamp thunks")
	_expect(b.slip.slip_sound == cues.rejection_slip, "the rejection slip scribbles")
	_expect(b.radio.static_sound == cues.radio_static, "the radio hisses while you wait")
	_expect(b.entrance.chime_sound == cues.entrance_chime, "the entrance chimes")
	_expect(b.entrance.chime_enabled, "and the chime is on by default")
	var doors_ok := true
	for door in b._all_doors():
		if door.locked_sound == null:
			doors_ok = false
	_expect(doors_ok, "every door rattles when locked")
	_expect(b.viewer.pickup_sound != null and b.terminal.key_sound != null,
		"papers rustle and the terminal clicks")
	_expect(b.room_tone != null and b.room_tone.stream != null and b.room_tone.playing,
		"the room tone is running")
	_expect(b.buzz != null and b.buzz.playing, "and so is the fluorescent buzz")
