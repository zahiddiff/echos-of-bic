extends RefCounted
class_name Dean

## Prof.

const NAME := "Prof. Sang-Woo Joo"

## Lines are indexed by the strike this arrival costs (1-5).
const ARRIVALS := {
	1: [
		"%s. There was an incident at the west entrance this evening.",
		"Nothing serious. I'd rather it hadn't happened on your shift, that's all.",
		"Go home. We'll pick it up tomorrow.",
	],
	2: [
		"%s.",
		"Second one. I've had to write this one up, which means somebody above me reads it.",
		"Shift's over. Go home.",
	],
	3: [
		"We've spoken about this, %s.",
		"Three. I'm told the paperwork is what matters here, so — the paperwork now has your name on it three times.",
		"Leave it. Go home.",
	],
	4: [
		"%s. Sit down. No — don't sit down, you're leaving.",
		"Four. I want to be clear, because I don't think I have been: one more and you're done here.",
		"I don't enjoy this part.",
	],
	5: [
		"%s.",
		"That's five.",
		"I'll need the access card. And the form — there's a form, for leaving. I'll send it to you.",
		"It's a shame about the filing. It was in good order.",
	],
}

## Said instead of an arrival line when the player has been calling security on people who did not deserve it.
const FALSE_FLAG_WARNING := [
	"%s — a word.",
	"Security have been up here three times this week for nothing.",
	"They'll stop coming. Think about what that means, next time you pick up the radio.",
]

## And when they do it again anyway.
const FALSE_FLAG_SENT_HOME := [
	"%s. Put the radio down.",
	"They've sent someone up for the fourth time tonight. For nothing, again.",
	"Go home. Come back tomorrow and use your judgement.",
]

## What the player sees on the way out, keyed to the ending.
const ENDINGS := {
	GameState.Ending.FIRED: [
		"You hand the card over at the desk you have been sitting at for eight nights.",
		"Nobody is at the other desk. Nobody has been, for a while.",
	],
	GameState.Ending.STANDARD: [
		"Shift eight ends the way the other seven did. The lights stay on behind you.",
		"There is a new name on the rota for next week. You don't recognise it.",
	],
	GameState.Ending.TRUE_END: [
		"Eight shifts. No incidents.",
		"Prof. Joo signs the last form without looking up, and says the building runs well when people pay attention.",
		"On the way out you pass the flyer by the entrance. It has been there a while. Nobody has taken it down.",
	],
}

## The lines for an arrival that costs `strike_number` (1-5).
static func arrival_lines(strike_number: int, player_name: String) -> PackedStringArray:
	var key := clampi(strike_number, 1, 5)
	var lines := PackedStringArray()
	for template: String in ARRIVALS[key]:
		lines.append(template % player_name if template.contains("%s") else template)
	return lines

static func false_flag_warning(player_name: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for template: String in FALSE_FLAG_WARNING:
		lines.append(template % player_name if template.contains("%s") else template)
	return lines

static func false_flag_sent_home(player_name: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for template: String in FALSE_FLAG_SENT_HOME:
		lines.append(template % player_name if template.contains("%s") else template)
	return lines

static func ending_lines(which: GameState.Ending) -> PackedStringArray:
	var lines := PackedStringArray()
	for line: String in ENDINGS.get(which, []):
		lines.append(line)
	return lines

## How he is playing it, for the actor and the animator later.
static func demeanour(strike_number: int) -> String:
	match clampi(strike_number, 1, 5):
		1: return "mildly irritated"
		2: return "annoyed"
		3: return "annoyed, formal"
		4: return "openly threatening"
		5: return "detached"
	return "neutral"
