extends RefCounted
class_name ThreatType

## The threat catalogue.

enum Kind {
	NONE,
	INFORMATION_SEEKER,
	THIEF,
	STALKER,
	FINALE,
}

## Equal weighting, and the Finale is deliberately not in here — it is never random.
const RANDOM_KINDS := [Kind.INFORMATION_SEEKER, Kind.THIEF, Kind.STALKER]

const LABELS := {
	Kind.NONE: "—",
	Kind.INFORMATION_SEEKER: "Information Seeker",
	Kind.THIEF: "Thief",
	Kind.STALKER: "Stalker",
	Kind.FINALE: "Finale Threat",
}

## Which tasks each threat hides behind.
const COVER_TASKS := {
	Kind.INFORMATION_SEEKER: [
		"transcript_print", "notarization", "scholarship_check",
		"enrollment_cert", "graduation_cert",
	],
	Kind.THIEF: [
		"mail_pickup", "dorm_key", "id_reissue", "lost_and_found",
	],
	Kind.STALKER: [
		"schedule_lookup", "room_lookup", "exam_schedule", "dorm_assignment",
	],
}

## The follow-up worth asking, and what it sounds like when it lands badly.
const PROBES := {
	Kind.INFORMATION_SEEKER: [
		["Who authorised this request?",
			"My supervisor did. He signed it — it should be on there somewhere."],
		["You're not the student named here. What's your relation?",
			"I'm a research assistant. I collect these for the whole lab, normally."],
	],
	Kind.THIEF: [
		["What's in the package?",
			"Books, I think. Or a charger. I didn't order it myself."],
		["I'll need to go get it. Can you wait at the counter?",
			"I can come round with you, it's quicker that way."],
	],
	Kind.STALKER: [
		["How do you know them?",
			"We're friends. From class. Well — she's in my year."],
		["What's their student number?",
			"I don't have it on me. But I know where she usually sits."],
	],
}

static func label(kind: Kind) -> String:
	return LABELS.get(kind, "—")

static func pick_random(rng: RandomNumberGenerator) -> Kind:
	return RANDOM_KINDS[rng.randi() % RANDOM_KINDS.size()]

static func cover_task_ids(kind: Kind) -> Array:
	return COVER_TASKS.get(kind, [])

static func probes_for(kind: Kind) -> Array:
	return PROBES.get(kind, [])

static func is_designed(kind: Kind) -> bool:
	return kind != Kind.FINALE

## Whether flagging was the right call.
static func should_be_flagged(kind: Kind) -> bool:
	return kind != Kind.NONE
