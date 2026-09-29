extends RefCounted
class_name DialogueAuthor

## Composes what a generated visitor says.

const THREAT_TELL_CHANCE := 0.75
const INNOCENT_TELL_CHANCE := 0.15

## Deliveries a nervous-but-innocent person plausibly shows.
const INNOCENT_TELLS := [
	DialogueLine.Delivery.HESITANT,
	DialogueLine.Delivery.OVER_EXPLAINS,
	DialogueLine.Delivery.CHECKS_TIME,
]

const THREAT_TELLS := [
	DialogueLine.Delivery.TOO_FAST,
	DialogueLine.Delivery.OVER_EXPLAINS,
	DialogueLine.Delivery.GOES_QUIET,
	DialogueLine.Delivery.CHECKS_EXIT,
	DialogueLine.Delivery.HESITANT,
]

const OPENINGS := {
	"id_reissue": "I lost my student card. I need a new one.",
	"transcript_print": "Could I get a transcript printed?",
	"enrollment_cert": "I need a certificate of enrollment, please.",
	"graduation_cert": "I'm here about my graduation certificate.",
	"notarization": "I need this document stamped by the office.",
	"schedule_lookup": "Could you look up a class schedule for me?",
	"course_add_drop": "I've got an add/drop form to hand in.",
	"room_lookup": "I can't find the building. Room 407?",
	"exam_schedule": "I need to ask about a makeup exam.",
	"scholarship_check": "Can you check if my scholarship application went through?",
	"visa_extension": "This is for my visa extension.",
	"residency_card": "My residency card needs renewing.",
	"work_permit": "I want to apply for a part-time work permit.",
	"address_change": "I moved. I need to register the new address.",
	"dorm_assignment": "I'm asking about a dorm transfer.",
	"dorm_key": "My access card stopped working.",
	"mail_pickup": "There's a package here for me, I think.",
	"bank_letter": "The bank needs a letter from the university.",
	"sim_letter": "I need a letter to register a phone number.",
	"lost_and_found": "Has anyone handed in a grey laptop bag?",
}

const CLOSINGS := [
	"Thanks. I'll wait over there.",
	"Okay. Thank you.",
	"Appreciate it.",
	"That's great, thanks.",
	"Right. Thanks.",
]

## Question, then the straight answer a legitimate requester gives.
const FOLLOW_UPS := [
	["What do you need it for?", "It's for an application. They asked for it in writing."],
	["Is this for you?", "Yeah, it's mine."],
	["Can you confirm the spelling of your name?", "Sure — it's the same as on the card."],
	["Which department are you in?", "%COLLEGE%. Second year."],
	["When do you need it by?", "Whenever's fine. This week, ideally."],
	["Have you been to this desk before?", "Once, last semester."],
]

## What the same question sounds like when it lands somewhere tender.
const TELL_ANSWERS := {
	DialogueLine.Delivery.TOO_FAST: "Yeah. Yeah, that's right.",
	DialogueLine.Delivery.OVER_EXPLAINS: "It's for the office, the one downstairs, because they said without it they can't process anything, and I already went there once and they sent me back here, so — that's why.",
	DialogueLine.Delivery.GOES_QUIET: "",
	DialogueLine.Delivery.CHECKS_EXIT: "…Sorry. What was the question?",
	DialogueLine.Delivery.CHECKS_TIME: "Sorry — how long does this usually take?",
	DialogueLine.Delivery.HESITANT: "…Yes. It's on the card.",
}

var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng

func compose(request: VisitorRequest) -> VisitorDialogue:
	var talk := VisitorDialogue.new()
	var who := request.visitor_name

	talk.opening = _line(who, OPENINGS.get(request.task_id, "Hi — I have a request."))
	talk.closing = _line(who, CLOSINGS[rng.randi() % CLOSINGS.size()])

	var tell_chance := THREAT_TELL_CHANCE if request.is_threat else INNOCENT_TELL_CHANCE
	var tell_index := -1
	var count := 1 if rng.randf() < 0.35 else 2
	if request.is_threat:
		count = 2
	if rng.randf() < tell_chance:
		tell_index = rng.randi() % count

	var pool := FOLLOW_UPS.duplicate()

	# A threat gets one question aimed at the thing their cover story is weakest on — the forged authorisation, the story that shifts, the friend whose student number they don't know.
	var probes := ThreatType.probes_for(request.threat_kind)
	if not probes.is_empty():
		var probe: Array = probes[rng.randi() % probes.size()]
		var probe_delivery: DialogueLine.Delivery = THREAT_TELLS[rng.randi() % THREAT_TELLS.size()]
		var probe_answer := _line(who, probe[1], probe_delivery)
		if probe_delivery == DialogueLine.Delivery.HESITANT:
			probe_answer.lead_in = rng.randf_range(1.0, 1.8)
		elif probe_delivery == DialogueLine.Delivery.GOES_QUIET:
			probe_answer.text = ""
			probe_answer.lead_in = 0.5
			probe_answer.hold = 2.2
		talk.follow_ups.append(VisitorDialogue.FollowUp.make(probe[0], probe_answer))
		count = maxi(count - 1, 0)
		tell_index = -1

	for slot in count:
		var pick := rng.randi() % pool.size()
		var pair: Array = pool[pick]
		pool.remove_at(pick)

		var answer: DialogueLine
		if slot == tell_index:
			var tells: Array = THREAT_TELLS if request.is_threat else INNOCENT_TELLS
			var delivery: DialogueLine.Delivery = tells[rng.randi() % tells.size()]
			answer = _line(who, TELL_ANSWERS[delivery], delivery)
			# Hesitation has to be a real pause, not a caption saying "pauses".
			if delivery == DialogueLine.Delivery.HESITANT:
				answer.lead_in = rng.randf_range(1.2, 2.0)
			elif delivery == DialogueLine.Delivery.GOES_QUIET:
				answer.lead_in = 0.5
				answer.hold = 2.2
		else:
			answer = _line(who, _fill(pair[1], request))

		talk.follow_ups.append(VisitorDialogue.FollowUp.make(pair[0], answer))

	return talk

func _fill(text: String, request: VisitorRequest) -> String:
	return text.replace("%COLLEGE%", request.college_code.to_upper())

func _line(speaker: String, text: String,
		delivery: DialogueLine.Delivery = DialogueLine.Delivery.NORMAL) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker = speaker
	line.text = text
	line.delivery = delivery
	return line
