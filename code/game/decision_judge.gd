extends RefCounted
class_name DecisionJudge

## Decides what a call actually was.

enum Verdict {
	CORRECT,           ## the right call
	MISSED_THREAT,     ## a threat was approved or rejected instead of flagged
	FALSE_FLAG,        ## security called on someone who did not deserve it
	PROCESSING_ERROR,  ## approved something invalid, or rejected something clean
}

## What the player should have done with this visitor.
enum RightCall { APPROVE, REJECT, FLAG }

## Decision values mirror BICBuilding.Decision.
const APPROVE := 0
const REJECT := 1
const FLAG := 2

static func right_call(request: VisitorRequest, rulebook: Rulebook) -> RightCall:
	if request.is_threat:
		return RightCall.FLAG
	if not rulebook.passes(request):
		return RightCall.REJECT
	return RightCall.APPROVE

static func judge(request: VisitorRequest, decision: int, rulebook: Rulebook) -> Verdict:
	var wanted := right_call(request, rulebook)

	if decision == FLAG:
		return Verdict.CORRECT if wanted == RightCall.FLAG else Verdict.FALSE_FLAG

	if request.is_threat:
		return Verdict.MISSED_THREAT

	var matched := (decision == APPROVE and wanted == RightCall.APPROVE) \
		or (decision == REJECT and wanted == RightCall.REJECT)
	return Verdict.CORRECT if matched else Verdict.PROCESSING_ERROR

static func verdict_name(verdict: Verdict) -> String:
	match verdict:
		Verdict.CORRECT: return "correct"
		Verdict.MISSED_THREAT: return "missed threat"
		Verdict.FALSE_FLAG: return "false flag"
		Verdict.PROCESSING_ERROR: return "processing error"
	return "?"

## Repetition and Physical wrongness are not visible on the rules sheet, so a player who rejects on those grounds is reading the room rather than the rulebook.
static func was_catchable_by_rulebook(request: VisitorRequest, rulebook: Rulebook) -> bool:
	return not rulebook.passes(request)
