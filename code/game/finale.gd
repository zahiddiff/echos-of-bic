extends RefCounted
class_name Finale

## The last night: the fifth incident turns into a lockdown, and someone gets past it.

enum Outcome { NONE, STOPPED, REACHED }

## Seconds the radio call takes against the walk to the meeting room decide it. Call first and they are stopped.
const PATIENCE_SECONDS := 70.0
## Once the radio is picked up they don't wait long. The walk takes about 10 s and the call 16 s,
## so calling before deciding wins with a few seconds to spare; stamping or refusing first loses.
const NERVE_SECONDS := 10.0
const WALK_SPEED := 0.9

const LOCKDOWN := [
	"%s. Stay at the desk.",
	"There's been another one. Whoever it was is still in the building.",
	"Security are locking the front doors and going through every room. Nobody comes in until they're done.",
	"Hold the desk. Don't let anyone past it.",
]

const OPENING := "Hi. Sorry. I left my laptop in the meeting room after the seminar. I just need the key."
const FOLLOW_UPS := [
	["How did you get in? The doors are locked.", "They were open when I came in.", DialogueLine.Delivery.TOO_FAST],
	["The seminar finished hours ago.", "I know. I came straight back when I noticed.", DialogueLine.Delivery.CHECKS_EXIT],
]
const CLOSING := "I'll only be a minute."
const LEAVING := "I'll just go and check."

## Over the radio, once it is settled.
const RADIO := {
	Outcome.STOPPED: [
		"%s. We have them. They were carrying a card that isn't theirs.",
		"That was the right call.",
	],
	Outcome.REACHED: [
		"%s. They were in the meeting room. In the student files.",
		"Stay where you are. I'm coming up.",
	],
}

## The Fired ending, told two ways.
const ENDINGS := {
	Outcome.STOPPED: [
		"Security walk them out through the front. They don't look back at the desk.",
		"In their bag: a card reported lost last spring, and a printed list of names with room numbers beside them.",
		"Prof. Joo reads the list twice. Then he asks for your access card. Five is five.",
	],
	Outcome.REACHED: [
		"Security find them at the meeting room table with the student files open, photographing each page.",
		"They don't run. The photographs have already gone wherever they were going.",
		"Prof. Joo asks for your access card. He seems most upset about the cabinet being left open.",
	],
}

static func lockdown_lines(player_name: String) -> PackedStringArray:
	return _fill(LOCKDOWN, player_name)

static func radio_lines(outcome: Outcome, player_name: String) -> PackedStringArray:
	return _fill(RADIO.get(outcome, []), player_name)

static func ending_lines(outcome: Outcome) -> PackedStringArray:
	return PackedStringArray(ENDINGS.get(outcome, []))

static func outcome_name(outcome: Outcome) -> String:
	return Outcome.keys()[outcome]

## Paperwork that passes every rule. Nothing on the desk is wrong; everything around it is.
static func build_request(rulebook: Rulebook, seed_value: int) -> VisitorRequest:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var request := RequestGenerator.new(rulebook, rng).clean_request(TaskPool.by_id("room_lookup"))
	var person := NameBank.random_name(rng)
	request.visitor_name = person
	request.form_name = person
	request.id_name = person
	request.task_id = "meeting_room_key"
	request.task_label = "Meeting room key"
	request.is_threat = true
	request.threat_kind = ThreatType.Kind.FINALE
	request.wrongness = VisitorRequest.Wrongness.NONE

	var talk := VisitorDialogue.new()
	talk.opening = _line(person, OPENING)
	for entry in FOLLOW_UPS:
		var answer := _line(person, entry[1])
		answer.delivery = entry[2]
		talk.follow_ups.append(VisitorDialogue.FollowUp.make(entry[0], answer))
	talk.closing = _line(person, CLOSING)
	request.dialogue = talk
	return request

## What the terminal says about them.
static func record_lines(request: VisitorRequest) -> PackedStringArray:
	return PackedStringArray([
		"RECORD: %s" % request.id_number.to_upper(),
		"",
		"NAME . . . . . %s" % request.id_name.to_upper(),
		"COLLEGE  . . . %s" % request.college_code.to_upper(),
		"STATUS . . . . WITHDRAWN",
		"CARD . . . . . REPORTED LOST, CANCELLED",
	])

static func _line(speaker: String, text: String) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker = speaker
	line.text = text
	return line

static func _fill(templates: Array, player_name: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for template: String in templates:
		lines.append(template % player_name if template.contains("%s") else template)
	return lines
