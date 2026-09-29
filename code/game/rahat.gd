extends RefCounted
class_name Rahat

## Rahat, the co-worker who walks you through shift one.

const NAME := "Rahat"

const COLD_OPEN := [
	"You're the new one? Right — Rahat. I do the other desk.",
	"It's not complicated. Someone comes in, they want something, you check they are who they say they are, and then you either do it or you don't.",
	"Rulebook's taped to the desk. Don't try to memorise it, nobody does. Just look at it.",
	"I'll be over there. Shout if something's weird.",
]

## One line per teaching moment, keyed to the visitor that carries it.
const TEACHING := {
	1: [
		"Okay — first one. Form's on the left, their card's on the right.",
		"Read the name on the form. Read the name on the card. They have to be the same name.",
		"That's it. That's the whole first rule.",
	],
	2: [
		"See the number on her card? BIC, then the year she started, then six digits.",
		"If the year's wrong, or it's five digits, or it's eight — that's not a card we issued.",
	],
	3: [
		"This one you have to actually look at. The photo on the card should be the person in front of you.",
		"Use the glass. Drag it over the photo, then over their face. Take your time, nobody minds.",
	],
	4: [
		"This one needs printing, so you'll have to go through to the back room.",
		"Takes a minute. Desk's on its own while you're gone — that's just how it is here.",
	],
	5: [
		"Department code goes on the form. There's a list on the desk.",
		"If it's not on the list, it's not a department. People write all sorts.",
	],
	6: [
		"Check the date it was issued, and how long it's good for.",
		"Half of these expire in ninety days and nobody reads that part until it's too late.",
	],
	7: [
		"Some things need a stamp from another office before they come to us.",
		"No stamp, no processing. Doesn't matter how right the rest of it is.",
	],
}

## Flag training: shown on someone obviously fine, and said out loud not to be a real call.
const FLAG_TRAINING := [
	"Last thing. See the radio?",
	"If someone's not right — properly not right, not just bad paperwork — you pick that up and security come.",
	"I'll show you on him. He's fine, he's completely fine, I'm not actually calling anyone. Watch.",
	"…and that's it. They come up, they walk the person out, you never find out what happened after.",
	"You'll want to be sure before you use it. They stop taking you seriously otherwise.",
]

## Section 13 step 7: the strike system, planted verbally.
const STAKES := [
	"One more thing and then I'll leave you alone.",
	"If you wave through someone you shouldn't have, it doesn't come back on you straight away.",
	"But it does come back. Prof. Joo comes down, and he's very polite about it, and that's somehow worse.",
	"Few of those and they stop scheduling you. So. Just — look at things properly.",
]

## Section 13 step 8: end on one small unresolved detail.
const CLOSING := [
	"That's you, then. You'll be fine.",
	"Oh — we get odd ones sometimes. Not dangerous odd. Just… people who don't quite add up.",
	"Anyway. Same time tomorrow.",
]

static func _fill(lines: Array, player_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in lines:
		out.append(line % player_name if line.contains("%s") else line)
	return out

static func cold_open(player_name: String) -> PackedStringArray:
	return _fill(COLD_OPEN, player_name)

## The line he gives before visitor `number` (1-based), or empty.
static func teaching_for(number: int, player_name: String) -> PackedStringArray:
	if not TEACHING.has(number):
		return PackedStringArray()
	return _fill(TEACHING[number], player_name)

static func flag_training(player_name: String) -> PackedStringArray:
	return _fill(FLAG_TRAINING, player_name)

static func stakes(player_name: String) -> PackedStringArray:
	return _fill(STAKES, player_name)

static func closing(player_name: String) -> PackedStringArray:
	return _fill(CLOSING, player_name)
