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
## Which of the 8 shifts to run.
@export_range(1, 8) var shift: int = 1
## 0 means a fresh seed each run.
@export var queue_seed: int = 0
## People walk in, queue, step up and leave.
@export var visitors_enabled: bool = true

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

func _ready() -> void:
	player.focus_changed.connect(hud._on_player_focus_changed)
	player.interacted.connect(hud._on_player_interacted)

	for door in _all_doors():
		door.refused.connect(_on_door_refused.bind(door))


	desk.seated.connect(_on_desk_seated)
	desk.stood_up.connect(_on_desk_stood_up)
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

	_start_shift()

	if GameState.has_player_name():
		hud.show_activity("Shift %d — %s" % [shift, GameState.player_name])

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

	runner.start(shift, queue_seed)
	records.load_records(_records_for_queue())

	print("[BIC] shift %d%s — %d visitors, %d threats, %d strikes left"
		% [shift, " (onboarding)" if runner.is_onboarding else "",
			runner.queue.size(), _threat_count(), GameState.strikes_remaining()])

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

	viewer.show_request(request)
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
	radio.abort()
	_clear_ticket()
	# Standing up does NOT skip anyone — they are still at the counter when you get back.

func _on_viewer_closed() -> void:
	pass

func _on_desk_action_clicked(action: Node) -> void:
	if desk.is_seated and action.has_method("interact"):
		action.interact(player)

func _on_approved(document: Node) -> void:
	_resolve(document, Decision.APPROVE, "Stamped APPROVED")

func _on_rejected(document: Node) -> void:
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
	if visitors_enabled and stage:
		stage.call_forward(request, runner.peek(1))
	if not desk.is_seated:
		return
	_on_desk_seated(player)
	var _unused := request

func _on_incident(request: VisitorRequest) -> void:
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
