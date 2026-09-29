extends RefCounted
class_name BuildingLayout

## Every measurement in the building, in one place.
##        -Z  ┌────────────────────────┐
##            │  MEETING ROOM          │  dead end
##            ├─────────────────┐  ▯   │
##            │  STORAGE        └──────│
##            ├─────────────────┐  ▯   │
##            │  MAIN FLOOR     └──────│
##            │   Rahat's desk (west)  ═══ ENTRANCE (sliding)
##            │   Player's desk (east) │
##            ├─────────────────┐  ▯   │
##        +Z  │  PRINT / CONFIDENTIAL  │
##            └────────────────────────┘

# --- Shell --------------------------------------------------------------------
const WALL_T := 0.2
const CEILING_H := 2.9
const DOOR_H := 2.1

const X_MIN := -4.5
const X_MAX := 4.5

const Z_MIN := -9.6            ## far (north) wall, behind the meeting room
const Z_MEETING_STORAGE := -6.0
const Z_STORAGE_MAIN := -3.0
const Z_MAIN_PRINT := 2.6
const Z_MAX := 5.8             ## near (south) wall, behind the print room

# --- Doorways -----------------------------------------------------------------
## A real single office door is ~0.9-1.0 m. 1.1 m keeps first-person navigation forgiving without looking like a loading bay.
const DOORWAY_WIDTH := 1.1
## Gap between the doorway and the east wall.
const DOORWAY_EAST_MARGIN := 0.6
const DOORWAY_X1 := X_MAX - DOORWAY_EAST_MARGIN
const DOORWAY_X0 := DOORWAY_X1 - DOORWAY_WIDTH

## Double sliding glass doors on the east wall of the main floor.
const ENTRANCE_Z0 := -2.2
const ENTRANCE_Z1 := -0.6

# --- The player's desk --------------------------------------------------------
## Counter runs east-west.
const COUNTER_X0 := 1.4
const COUNTER_X1 := 3.8
const COUNTER_Z := 1.05
const COUNTER_DEPTH := 0.7
const COUNTER_H := 1.05

const PLAYER_SPAWN := Vector3(3.0, 0.05, 2.0)
## Where the player's feet go when they sit down to work the desk.
const SEAT := Vector3(3.0, 0.0, 2.0)
const SEAT_PITCH_DEGREES := -14.0
## The tray of papers you press E on.
const DESK_STATION := Vector3(3.1, COUNTER_H, 1.05)

## Where a visitor stands to be served — across the counter from the player.
const VISITOR_SPOT := Vector3(3.05, 0.0, 0.05)
## Where they stand while waiting, just inside the doors.
const QUEUE_SPOT := Vector3(2.4, 0.0, -1.6)

# --- Rahat's desk -------------------------------------------------------------
const RAHAT_DESK := Vector3(-2.4, 0.0, -0.4)

# --- Derived points -----------------------------------------------------------

static func doorway_centre_x() -> float:
	return (DOORWAY_X0 + DOORWAY_X1) * 0.5

static func entrance_centre() -> Vector3:
	return Vector3(X_MAX + WALL_T * 0.5, 0.0, (ENTRANCE_Z0 + ENTRANCE_Z1) * 0.5)

static func counter_centre() -> Vector3:
	return Vector3((COUNTER_X0 + COUNTER_X1) * 0.5, COUNTER_H * 0.5, COUNTER_Z)

static func counter_back_z() -> float:
	return COUNTER_Z + COUNTER_DEPTH * 0.5

static func counter_front_z() -> float:
	return COUNTER_Z - COUNTER_DEPTH * 0.5

static func room_depths() -> Dictionary:
	return {
		"meeting": Z_MEETING_STORAGE - Z_MIN,
		"storage": Z_STORAGE_MAIN - Z_MEETING_STORAGE,
		"main": Z_MAIN_PRINT - Z_STORAGE_MAIN,
		"print": Z_MAX - Z_MAIN_PRINT,
	}

static func width() -> float:
	return X_MAX - X_MIN

## Places a standing adult must fit, with nothing but floor underfoot.
static func walkable_points() -> Dictionary:
	var door_x := doorway_centre_x()
	return {
		"behind the counter (spawn)": Vector3(PLAYER_SPAWN.x, 0, PLAYER_SPAWN.z),
		"visitor side of the counter": VISITOR_SPOT,
		"just inside the entrance": QUEUE_SPOT,
		"lane to the print room door": Vector3(door_x, 0, Z_MAIN_PRINT - 0.45),
		"inside the print room": Vector3(door_x, 0, Z_MAIN_PRINT + 1.6),
		"beside Rahat's desk": Vector3(RAHAT_DESK.x - 1.35, 0, RAHAT_DESK.z),
		"main floor, west end": Vector3(X_MIN + 1.2, 0, Z_STORAGE_MAIN + 0.8),
		"storage interior": Vector3(0.0, 0, (Z_MEETING_STORAGE + Z_STORAGE_MAIN) * 0.5),
		"meeting room interior": Vector3(door_x - 0.9, 0, Z_MIN + 1.2),
	}
