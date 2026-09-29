extends Resource
class_name AudioCues

## Every sound the game asks for, in one place.

@export_group("The building")
@export var entrance_chime: AudioStream
@export var entrance_whoosh: AudioStream
@export var door_open: AudioStream
@export var door_locked: AudioStream

@export_group("Ambience")
## HVAC hum, distant chatter, a door down the hall.
@export var room_tone: AudioStream
## Later shifts, as the building drains of people.
@export var room_tone_late: AudioStream
@export var fluorescent_buzz: AudioStream

@export_group("The desk")
## The approval stamp.
@export var stamp: AudioStream
@export var rejection_slip: AudioStream
@export var paper_pickup: AudioStream
@export var paper_drop: AudioStream
@export var terminal_key: AudioStream
@export var terminal_error: AudioStream

@export_group("The radio")
@export var radio_pickup: AudioStream
## Static, held for the length of the call.
@export var radio_static: AudioStream
@export var radio_done: AudioStream

## Room tone for a given shift.
func ambience_for(shift: int) -> AudioStream:
	if shift >= 6 and room_tone_late:
		return room_tone_late
	return room_tone

## Which cues still have no file behind them.
func missing() -> PackedStringArray:
	var gaps := PackedStringArray()
	for property in get_property_list():
		if property["type"] != TYPE_OBJECT:
			continue
		var key: String = property["name"]
		if key.begins_with("script") or key.begins_with("resource"):
			continue
		if get(key) == null:
			gaps.append(key)
	return gaps

func has_any_audio() -> bool:
	return missing().size() < 16
