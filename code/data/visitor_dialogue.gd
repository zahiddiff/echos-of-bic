extends Resource
class_name VisitorDialogue

## Everything one visitor might say at the desk.

@export var opening: DialogueLine
## One or two.
@export var follow_ups: Array[FollowUp] = []
@export var closing: DialogueLine

class FollowUp extends Resource:
	## What the player asks, as it appears in the prompt list.
	@export var question: String = ""
	@export var answer: DialogueLine
	## Once asked, it stays asked — no farming the same question for tells.
	var asked: bool = false

	static func make(new_question: String, new_answer: DialogueLine) -> FollowUp:
		var follow_up := FollowUp.new()
		follow_up.question = new_question
		follow_up.answer = new_answer
		return follow_up

func available_follow_ups() -> Array[FollowUp]:
	var open_questions: Array[FollowUp] = []
	for follow_up in follow_ups:
		if not follow_up.asked:
			open_questions.append(follow_up)
	return open_questions

func has_questions_left() -> bool:
	return not available_follow_ups().is_empty()

func reset() -> void:
	for follow_up in follow_ups:
		follow_up.asked = false
