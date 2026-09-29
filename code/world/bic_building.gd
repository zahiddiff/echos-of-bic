extends Node3D
class_name BICBuilding

## The building, and the night that runs inside it.

@onready var player: PlayerController = $Player
@onready var hud: InteractHUD = $InteractHUD
@onready var entrance: SlidingEntrance = $Doors/Entrance
@onready var desk: DeskStation = $Props/PlayerDesk/DeskStation
@onready var viewer: DocumentViewer = $DocumentViewer
@onready var stamp: StampAction = $Props/PlayerDesk/ApprovalStamp
@onready var slip: RejectionSlip = $Props/PlayerDesk/RejectionSlip
@onready var radio: DeskRadio = $Props/PlayerDesk/DeskRadio
@onready var records: RecordsComputer = $Props/PlayerDesk/RecordsComputer
@onready var terminal: TerminalScreen = $TerminalScreen
@onready var dialogue: DialogueView = $DialogueView

## What the player did about a visitor.
enum Decision { APPROVE, REJECT, FLAG }

signal decision_made(request: VisitorRequest, decision: Decision)

@export_group("Shift")
## Which of the 8 shifts to run. 0 continues the current run.
@export_range(0, 8) var shift: int = 0
## 0 means a fresh seed each run.
@export var queue_seed: int = 0
## People walk in, queue, step up and leave.
@export var visitors_enabled: bool = true
## How long a decision stays on the desk before the next visitor's papers come up.
@export var decision_pause: float = 1.1
## Night shift starts at this hour.
@export var start_hour: int = 21
## Releasing the mouse away from the desk pauses the game. Off for screenshot tools.
@export var pause_on_release: bool = true
## Clocking out loads the next night. Off in tests, which own the scene tree.
@export var reload_on_continue: bool = true

## Every sound in the building.
@export var audio: AudioCues = preload("res://assets/audio/bic_audio_cues.tres")

var rulebook := Rulebook.new()
var runner: ShiftRunner
var room_tone: AudioStreamPlayer
var stage: VisitorStage
var buzz: AudioStreamPlayer
var story := EnvironmentStory.new()
var lighting := ShiftLighting.new()

var _ticket: VisitorTicket

var status_bar: StatusBar
var report: ShiftReport
var pause_menu: PauseMenu
## What the player did this shift, for the report. No verdicts: the desk never says who was right.
var tally := {"approved": 0, "rejected": 0, "flagged": 0}
var clock_minutes: float = 0.0
var _end_reason: int = -1
var collection_points: Array[CollectionPoint] = []
## A thief using a back-room errand as cover has moved round the counter while the desk was empty.
var _slipped_away: bool = false

const TITLE_SCENE := "res://scenes/ui/name_entry.tscn"
## Game minutes that pass per real second, and per visitor served.
const MINUTES_PER_SECOND := 0.25
const MINUTES_PER_VISITOR := 14.0

func _ready() -> void:
	if shift == 0:
		shift = GameState.shift
	else:
		GameState.shift = shift
	clock_minutes = start_hour * 60.0
	_build_interface()

	player.focus_changed.connect(hud._on_player_focus_changed)
	player.interacted.connect(hud._on_player_interacted)

	for door in _all_doors():
		door.refused.connect(_on_door_refused.bind(door))


	desk.seated.connect(_on_desk_seated)
	desk.stood_up.connect(_on_desk_stood_up)
	dialogue.follow_up_asked.connect(func(_f: VisitorDialogue.FollowUp) -> void: PlaytestLog.note("follow_up"))
	viewer.photo_inspected.connect(func(_s: String) -> void: PlaytestLog.note("magnifier"))
	records.looked_up.connect(func(_q: String, _found: bool) -> void: PlaytestLog.note("lookup"))
	viewer.closed.connect(_on_viewer_closed)

	stamp.document_approved.connect(_on_approved)
	slip.document_rejected.connect(_on_rejected)
	radio.call_completed.connect(_on_flag_completed)
	radio.call_started.connect(_on_flag_started)

	terminal.attach(records)
	# Only one set of instructions on screen at a time.
	records.opened.connect(func() -> void: viewer.hint_label.visible = false)
	records.closed.connect(func() -> void: viewer.hint_label.visible = viewer.visible)

	# Seated, the camera is fixed and the mouse is free, so the desk objects are reached by clicking rather than by the walking raycast.
	for action in [stamp, slip, radio, records]:
		var click: ClickTarget = action.get_node("ClickTarget")
		click.clicked.connect(_on_desk_action_clicked)
		click.hovered.connect(_on_desk_action_hovered)

	# The building reacts to what this run has actually been, before the night starts.
	lighting.apply(self, shift)
	_apply_audio()
	story.beat_appeared.connect(_on_story_beat)
	story.bind(self)

	stage = VisitorStage.new()
	stage.name = "VisitorStage"
	add_child(stage)
	stage.rahat = get_node_or_null("Props/OtherDesk/RahatThings/Rahat") as VisitorFigure
	dialogue.line_started.connect(func(line: DialogueLine) -> void:
		stage.perform(line, dialogue.reading_speed))

	_build_collection_points()
	_start_shift()

	if GameState.has_player_name():
		hud.show_activity("Shift %d — %s" % [shift, GameState.player_name])

## The printer and the mailroom shelf in the print room, where physical tasks are fetched from.
func _build_collection_points() -> void:
	var room := get_node_or_null("Props/PrintRoom")
	if room == null:
		return
	var printer := CollectionPoint.new()
	printer.name = "PrinterTray"
	printer.kind = "printout"
	printer.idle_prompt = "Printer"
	printer.position = Vector3(-3.0, 0.575, BuildingLayout.Z_MAX - 0.7)
	room.add_child(printer)
	printer.setup(Vector3(0.98, 1.2, 0.78), Vector3(0.0, 0.59, 0.05), Vector3(0.3, 0.02, 0.4), Color(0.96, 0.96, 0.93))
	var shelf := CollectionPoint.new()
	shelf.name = "MailroomShelf"
	shelf.kind = "parcel"
	shelf.idle_prompt = "Mailroom shelf"
	shelf.position = Vector3(BuildingLayout.X_MIN + 0.25, 0.95, BuildingLayout.Z_MAIN_PRINT + 0.9)
	room.add_child(shelf)
	shelf.setup(Vector3(0.58, 1.95, 1.48), Vector3(0.05, 0.12, 0.1), Vector3(0.34, 0.24, 0.3), Color(0.55, 0.42, 0.28))
	for point: CollectionPoint in [printer, shelf]:
		point.collected.connect(_on_item_collected)
		collection_points.append(point)

func _refresh_collection() -> void:
	var request := current_request()
	for point in collection_points:
		point.wait_for(request)

func _on_item_collected(request: VisitorRequest) -> void:
	hud.show_activity("You have the %s. Take it back to the desk." % request.collected_label().to_lower())
	PlaytestLog.note("collected")
	PlaytestLog.event("collected", {"task": request.task_id})
	if _slipped_away:
		# They hear you coming back.
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if _slipped_away and stage.at_counter_request == request:
				_slipped_away = false
				stage.step_back_to_counter())

## Stamp stays locked until whatever the task needs has been fetched.
func _update_stamp_lock(request: VisitorRequest) -> void:
	var waiting := request != null and request.needs_collection() and not request.collected
	stamp.locked = waiting
	if waiting:
		stamp.locked_prompt_text = "Approve: fetch the %s first" % request.collected_label().to_lower()

func _build_interface() -> void:
	status_bar = StatusBar.new()
	status_bar.name = "StatusBar"
	add_child(status_bar)
	report = ShiftReport.new()
	report.name = "ShiftReport"
	add_child(report)
	report.continue_requested.connect(_on_report_continue)
	report.new_run_requested.connect(_on_new_run)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.quit_requested.connect(func() -> void:
		get_tree().change_scene_to_file(TITLE_SCENE))
	GameState.strike_taken.connect(status_bar.set_strikes)

func _process(delta: float) -> void:
	if runner and not runner.shift_over:
		clock_minutes += delta * MINUTES_PER_SECOND
	status_bar.set_clock(clock_text())
	status_bar.set_waiting(visitors_remaining())
	# A released mouse away from the desk means the player has stepped out of the game.
	if _pause_allowed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED 			and not desk.is_seated and not report.is_showing and not pause_menu.is_open:
		pause_menu.open("Shift %d  ·  %s" % [shift, clock_text()])
		PlaytestLog.event("paused")

func _pause_allowed() -> bool:
	return pause_on_release and DisplayServer.get_name() != "headless"

func clock_text() -> String:
	var total := int(clock_minutes) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]

func _start_shift() -> void:
	runner = ShiftRunner.new()
	runner.name = "ShiftRunner"
	runner.rulebook = rulebook
	add_child(runner)

	runner.visitor_ready.connect(_on_visitor_ready)
	runner.shift_ended.connect(_on_shift_ended)
	runner.incident_occurred.connect(_on_incident)
	runner.dean_arrived.connect(_on_dean_arrived)
	runner.dean_warning.connect(_on_dean_warning)
	runner.sent_home.connect(_on_dean_warning)
	runner.mentor_line.connect(_on_mentor_line)
	runner.rule_taught.connect(_on_rule_taught)
	runner.decision_judged.connect(_on_decision_judged)

	runner.shift_started.connect(func(number: int, count: int) -> void:
		PlaytestLog.begin_shift(number, ShiftSchedule.is_onboarding(number), count, GameState.strikes_remaining()))
	runner.start(shift, queue_seed)
	status_bar.set_shift(shift, runner.is_onboarding, GameState.demo)
	records.load_records(_records_for_queue())

	print("[BIC] shift %d%s — %d visitors, %d threats, %d strikes left"
		% [shift, " (onboarding)" if runner.is_onboarding else "",
			runner.queue.size(), _threat_count(), GameState.strikes_remaining()])

## Browsers only grant mouse capture inside a click, so clicking while walking recaptures it.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not desk.is_seated:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _all_doors() -> Array[Door]:
	var found: Array[Door] = []
	for node in $Doors.get_children():
		if node is Door:
			found.append(node)
	return found

func _threat_count() -> int:
	var total := 0
	for request in runner.queue:
		if request.is_threat:
			total += 1
	return total

## Every visitor in the queue has a record on file.
func _records_for_queue() -> Dictionary:
	var table := {}
	for request in runner.queue:
		table[request.id_number.to_upper()] = RecordsComputer.record_for(request)
	return table

func current_request() -> VisitorRequest:
	return runner.current() if runner else null

func visitors_remaining() -> int:
	return runner.visitors_remaining() if runner else 0

## Debug helper — step past whoever is at the desk without judging them.
func skip_visitor() -> void:
	if runner and runner.current() != null:
		runner.index += 1
		var next := runner.current()
		if next:
			runner.visitor_ready.emit(next)

# --- The desk -----------------------------------------------------------------

func _on_desk_seated(_player: Node) -> void:
	var request := current_request()
	if request == null:
		hud.show_activity("Nobody waiting.")
		return

	_ticket = VisitorTicket.of(request)
	add_child(_ticket)
	stamp.load_document(_ticket)
	slip.load_document(_ticket)
	radio.load_document(_ticket)
	_update_stamp_lock(request)
	if _slipped_away:
		# Back before they expected you.
		_slipped_away = false
		stage.step_back_to_counter()

	viewer.show_request(request)
	viewer.show_rulebook(rulebook)
	PlaytestLog.visitor_shown(request, runner.index)
	hud.visible = false
	get_viewport().physics_object_picking = true

	if request.dialogue:
		request.dialogue.reset()
		dialogue.begin(request.dialogue)

func _on_desk_stood_up(_player: Node) -> void:
	viewer.visible = false
	terminal.dismiss()
	dialogue.visible = false
	hud.visible = true
	get_viewport().physics_object_picking = false
	PlaytestLog.stood_up()
	radio.abort()
	_clear_ticket()
	# Standing up does NOT skip anyone — they are still at the counter when you get back.
	_maybe_slip_away(current_request())

## A thief sent to wait while you fetch something uses the empty desk.
func _maybe_slip_away(request: VisitorRequest) -> void:
	if request == null or not visitors_enabled or not request.is_threat \
			or request.threat_kind != ThreatType.Kind.THIEF \
			or not request.needs_collection() or request.collected:
		return
	await get_tree().create_timer(4.0).timeout
	if not is_inside_tree() or desk.is_seated or request.collected or current_request() != request:
		return
	_slipped_away = true
	stage.slip_behind_counter()
	PlaytestLog.event("thief_behind_counter")

func _on_viewer_closed() -> void:
	pass

func _on_desk_action_clicked(action: Node) -> void:
	if not desk.is_seated or not action.has_method("interact"):
		return
	if action == stamp and stamp.locked:
		var request := current_request()
		if request:
			viewer.show_hint("The %s is still in the print room. Fetch it before you approve." %
				request.collected_label().to_lower())
		return
	action.interact(player)

func _on_desk_action_hovered(action: Node, inside: bool) -> void:
	if not desk.is_seated:
		return
	if inside and action.has_method("get_prompt"):
		viewer.show_hint("Click: %s" % action.get_prompt())
	else:
		viewer.clear_hint()

func _on_approved(document: Node) -> void:
	if document == _ticket:
		viewer.stamp_mark(true)
	_resolve(document, Decision.APPROVE, "Stamped APPROVED")

func _on_rejected(document: Node) -> void:
	if document == _ticket:
		viewer.stamp_mark(false)
	_resolve(document, Decision.REJECT, "Rejection slip filled out")

func _on_flag_started(_document: Node) -> void:
	hud.show_activity("Radio: calling security…")

func _on_flag_completed(document: Node) -> void:
	_resolve(document, Decision.FLAG, "Security escorted them out")

func _resolve(document: Node, decision: Decision, note: String) -> void:
	var ticket := document as VisitorTicket
	if ticket == null:
		return
	var request := ticket.request

	# Deliberately no "correct!" feedback.
	hud.show_activity(note)
	PlaytestLog.decision_made(int(decision))
	tally[["approved", "rejected", "flagged"][int(decision)]] += 1
	clock_minutes += MINUTES_PER_VISITOR
	decision_made.emit(request, decision)

	_clear_ticket()

	# They leave before the next person steps up.
	if visitors_enabled:
		if decision == Decision.FLAG:
			stage.escort_out()
		else:
			stage.dismiss()

	runner.resolve(int(decision))

func _clear_ticket() -> void:
	stamp.load_document(null)
	slip.load_document(null)
	radio.load_document(null)
	if is_instance_valid(_ticket):
		_ticket.queue_free()
	_ticket = null

# --- The night ----------------------------------------------------------------

func _on_visitor_ready(request: VisitorRequest) -> void:
	_slipped_away = false
	_refresh_collection()
	_update_stamp_lock(request)
	if visitors_enabled and stage:
		stage.call_forward(request, runner.peek(1))
	if not desk.is_seated:
		return
	# Leave the decision on the desk for a moment before the next papers come up.
	if decision_pause > 0.0 and viewer.visible:
		await get_tree().create_timer(decision_pause).timeout
		if not desk.is_seated or current_request() != request:
			return
	_on_desk_seated(player)

func _on_decision_judged(request: VisitorRequest, verdict: DecisionJudge.Verdict) -> void:
	var broken := PackedStringArray()
	for finding in rulebook.violations(request):
		broken.append(finding.title())
	PlaytestLog.decision_judged(request, verdict, broken)

func _on_incident(request: VisitorRequest) -> void:
	PlaytestLog.event("incident", {"threat": ThreatType.Kind.keys()[request.threat_kind]})
	# Somewhere else in the building, hours after the fact.
	hud.show_activity("Something has happened downstairs.")
	var _unused := request

func _on_dean_arrived(lines: PackedStringArray, strike_number: int) -> void:
	if desk.is_seated:
		desk.stand()
	viewer.visible = false
	terminal.dismiss()
	hud.visible = true
	if visitors_enabled:
		stage.dean_arrives()
	dialogue.play_sequence(Dean.NAME, lines)
	print("[BIC] incident — strike %d (%s), %d left"
		% [strike_number, Dean.demeanour(strike_number), GameState.strikes_remaining()])

func _on_dean_warning(lines: PackedStringArray) -> void:
	dialogue.play_sequence(Dean.NAME, lines)

## Shift one only.
func _on_mentor_line(lines: PackedStringArray) -> void:
	dialogue.play_sequence(Rahat.NAME, lines)

func _on_rule_taught(_rule: Rulebook.Rule, title: String) -> void:
	hud.show_activity("Rulebook: %s" % title)

## Logged, never surfaced.
func _on_story_beat(id: String, note: String) -> void:
	print("[BIC] environment: %s (%s)" % [note, id])

func _on_shift_ended(reason: ShiftRunner.EndReason) -> void:
	var how := "shift finished"
	if reason == ShiftRunner.EndReason.INCIDENT:
		how = "sent home after an incident"
	elif reason == ShiftRunner.EndReason.SENT_HOME:
		how = "sent home over the radio calls"
	hud.show_activity("Shift over — %s." % how)
	print("[BIC] %s. strikes left: %d" % [how, GameState.strikes_remaining()])
	# An incident changes the building.
	story.refresh()
	_end_reason = reason
	PlaytestLog.end_shift(ShiftRunner.EndReason.keys()[reason], GameState.strikes_remaining())
	_show_report_when_quiet()

## Let whoever is talking finish, then close the night.
func _show_report_when_quiet() -> void:
	await get_tree().create_timer(1.5).timeout
	while dialogue.is_busy():
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if desk.is_seated:
		desk.stand()
	viewer.visible = false
	terminal.dismiss()
	dialogue.visible = false
	hud.visible = false
	status_bar.visible = false
	report.show_report(shift_summary())

func shift_summary() -> Dictionary:
	return {
		"shift": shift,
		"training": runner.is_onboarding,
		"reason": _end_reason,
		"seen": runner.index,
		"total": runner.queue.size(),
		"approved": tally["approved"],
		"rejected": tally["rejected"],
		"flagged": tally["flagged"],
		"strikes_left": GameState.strikes_remaining(),
		"clock_out": clock_text(),
		"run_over": GameState.run_over or GameState.is_final_shift() 			or (GameState.demo and shift >= GameState.DEMO_LAST_SHIFT),
	}

func _on_report_continue() -> void:
	if not report.feedback.is_empty():
		PlaytestLog.shift_feedback(report.feedback)
	runner.close_out()
	if GameState.run_over:
		PlaytestLog.end_run(GameState.ending_name(GameState.ending))
		report.show_ending(GameState.ending, Dean.ending_lines(GameState.ending))
		return
	if GameState.demo_finished():
		PlaytestLog.end_run("Demo complete")
		report.show_demo_end(GameState.strikes_remaining(), GameState.incident_count())
		return
	# The next night, same building.
	shift = 0
	if reload_on_continue:
		get_tree().reload_current_scene()

func _on_new_run() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(TITLE_SCENE)

# --- Doors --------------------------------------------------------------------

func _on_door_refused(_player: Node, door: Door) -> void:
	hud.show_activity("%s won't open." % door.name)


# --- Sound ----------------------------------------------------------------------

## Hand every object in the building its sound, and start the room tone.
func _apply_audio() -> void:
	if audio == null:
		return

	stamp.stamp_sound = audio.stamp
	slip.slip_sound = audio.rejection_slip
	radio.static_sound = audio.radio_static
	radio.pickup_sound = audio.radio_pickup
	radio.done_sound = audio.radio_done

	entrance.chime_sound = audio.entrance_chime
	entrance.open_sound = audio.entrance_whoosh
	entrance.close_sound = audio.entrance_whoosh

	for door in _all_doors():
		door.open_sound = audio.door_open
		door.close_sound = audio.door_open
		door.locked_sound = audio.door_locked

	viewer.pickup_sound = audio.paper_pickup
	viewer.drop_sound = audio.paper_drop
	terminal.key_sound = audio.terminal_key
	terminal.error_sound = audio.terminal_error

	room_tone = _bed("RoomTone", audio.ambience_for(shift), 0.0)
	buzz = _bed("FluorescentBuzz", audio.fluorescent_buzz, -4.0)

func _bed(bed_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = bed_name
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	if stream:
		player.play()
	return player
