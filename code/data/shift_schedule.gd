extends RefCounted
class_name ShiftSchedule

## The 8-shift curve: 8/9/10/11 visitors and 1/2/3/4 threats, per pair of shifts.

const TOTAL_SHIFTS := 8
const FIRST_SHIFT := 1
const ONBOARDING_SHIFT_IS_CLEAN := true

## Shift 1 is scripted;.
static func is_onboarding(shift: int) -> bool:
	return shift == FIRST_SHIFT

static func visitors_for(shift: int) -> int:
	var band := _band(shift)
	return 8 + band

static func threats_for(shift: int) -> int:
	if ONBOARDING_SHIFT_IS_CLEAN and is_onboarding(shift):
		return 0
	return 1 + _band(shift)

## Roughly what fraction of a shift's visitors are threats — the "chance per visitor" column.
static func threat_share(shift: int) -> float:
	var visitors := visitors_for(shift)
	if visitors <= 0:
		return 0.0
	return float(threats_for(shift)) / float(visitors)

## Total threat encounters across a full run.
static func total_threats() -> int:
	var total := 0
	for shift in range(FIRST_SHIFT, TOTAL_SHIFTS + 1):
		total += threats_for(shift)
	return total

## How obvious wrongness should be, 1.0 early and tightening later.
static func difficulty_for(shift: int) -> float:
	var span := maxf(float(TOTAL_SHIFTS - FIRST_SHIFT), 1.0)
	var progress := clampf(float(shift - FIRST_SHIFT) / span, 0.0, 1.0)
	return lerpf(0.85, 0.25, progress)

static func is_valid(shift: int) -> bool:
	return shift >= FIRST_SHIFT and shift <= TOTAL_SHIFTS

## 0 for shifts 1-2, 1 for 3-4, 2 for 5-6, 3 for 7-8.
static func _band(shift: int) -> int:
	var clamped := clampi(shift, FIRST_SHIFT, TOTAL_SHIFTS)
	return (clamped - 1) / 2
