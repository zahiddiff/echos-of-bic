extends Resource
class_name DialogueLine

## One spoken line and, optionally, how it was delivered.

## How the line is performed.
enum Delivery {
	NORMAL,
	TOO_FAST,       ## answered before the question finished — rehearsed
	HESITANT,       ## a beat too long before starting
	OVER_EXPLAINS,  ## more detail than the question needed
	GOES_QUIET,     ## no answer at all
	CHECKS_EXIT,    ## glances toward the door first
	CHECKS_TIME,    ## glances at the clock or their phone
}

@export_multiline var text: String = ""
@export var speaker: String = ""
@export var delivery: Delivery = Delivery.NORMAL

## Seconds of silence before the line starts.
@export var lead_in: float = 0.0
## Seconds the subtitle stays up. 0 means derive it from the text length.
@export var hold: float = 0.0

@export var voice: AudioStream

func display_seconds(reading_speed: float = 15.0) -> float:
	if hold > 0.0:
		return hold
	return clampf(text.length() / reading_speed, 1.4, 7.0)

func is_tell() -> bool:
	return delivery != Delivery.NORMAL
