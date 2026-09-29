extends RefCounted
class_name PortraitFactory

## Procedural ID photos. Deterministic per FaceTraits, shaded with a single key light.

enum Hair { SHORT, LONG, BUN, BUZZ, SIDE_PART }
enum FacialHair { NONE, STUBBLE, MOUSTACHE, BEARD }

## Rendered below target size then upscaled: softer, and cheap enough for web builds.
const RENDER_SCALE := 0.67

const SKIN_TONES := [
	Color(0.94, 0.80, 0.70), Color(0.89, 0.72, 0.60), Color(0.82, 0.64, 0.50),
	Color(0.74, 0.55, 0.41), Color(0.64, 0.46, 0.33), Color(0.55, 0.38, 0.27),
	Color(0.45, 0.30, 0.21), Color(0.36, 0.24, 0.17),
]
const HAIR_COLOURS := [
	Color(0.08, 0.07, 0.07), Color(0.12, 0.09, 0.08), Color(0.20, 0.14, 0.10),
	Color(0.30, 0.21, 0.14), Color(0.42, 0.30, 0.19), Color(0.38, 0.19, 0.12),
]
const GREY_HAIR := Color(0.58, 0.57, 0.56)
const EYE_COLOURS := [
	Color(0.20, 0.12, 0.08), Color(0.28, 0.17, 0.10), Color(0.36, 0.26, 0.14),
	Color(0.30, 0.38, 0.44), Color(0.28, 0.36, 0.24),
]
const CLOTHES := [
	Color(0.14, 0.17, 0.25), Color(0.30, 0.31, 0.33), Color(0.10, 0.10, 0.11),
	Color(0.28, 0.30, 0.22), Color(0.36, 0.16, 0.18), Color(0.55, 0.48, 0.38),
	Color(0.26, 0.34, 0.46), Color(0.82, 0.82, 0.80),
]
const INNER := [
	Color(0.92, 0.92, 0.90), Color(0.74, 0.82, 0.90), Color(0.60, 0.60, 0.62),
	Color(0.12, 0.12, 0.13),
]

## Every knob a face has.
class FaceTraits extends RefCounted:
	var seed: int
	var skin: Color
	var hair: Color
	var eyes: Color
	var clothes: Color
	var inner: Color
	var hair_style: int
	var facial_hair: int
	var glasses: bool
	var face_width: float
	var face_height: float
	var jaw: float
	var eye_spacing: float
	var eye_height: float
	var brow_thickness: float
	var brow_tilt: float
	var nose_width: float
	var hair_height: float
	var has_mole: bool
	var mole_side: int
	## Body height multiplier for the 3D figure.
	var height: float

	func duplicate_traits() -> FaceTraits:
		var copy := FaceTraits.new()
		for key in ["seed", "skin", "hair", "eyes", "clothes", "inner", "hair_style",
				"facial_hair", "glasses", "face_width", "face_height", "jaw", "eye_spacing",
				"eye_height", "brow_thickness", "brow_tilt", "nose_width", "hair_height",
				"has_mole", "mole_side", "height"]:
			copy.set(key, get(key))
		return copy

static func traits_for(seed_value: int) -> FaceTraits:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var t := FaceTraits.new()
	t.seed = seed_value
	t.skin = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	t.hair = HAIR_COLOURS[rng.randi() % HAIR_COLOURS.size()]
	if rng.randf() < 0.06:
		t.hair = GREY_HAIR
	t.eyes = EYE_COLOURS[rng.randi() % EYE_COLOURS.size()]
	t.clothes = CLOTHES[rng.randi() % CLOTHES.size()]
	t.inner = INNER[rng.randi() % INNER.size()]
	t.hair_style = rng.randi() % 5
	var beard_roll := rng.randf()
	t.facial_hair = FacialHair.NONE
	if t.hair_style != Hair.LONG and t.hair_style != Hair.BUN:
		if beard_roll < 0.14:
			t.facial_hair = FacialHair.STUBBLE
		elif beard_roll < 0.20:
			t.facial_hair = FacialHair.MOUSTACHE
		elif beard_roll < 0.27:
			t.facial_hair = FacialHair.BEARD
	t.glasses = rng.randf() < 0.22
	t.face_width = rng.randf_range(0.30, 0.37)
	t.face_height = rng.randf_range(0.37, 0.43)
	t.jaw = rng.randf_range(0.14, 0.34)
	t.eye_spacing = rng.randf_range(0.135, 0.17)
	t.eye_height = rng.randf_range(-0.012, 0.012)
	t.brow_thickness = rng.randf_range(0.012, 0.022)
	t.brow_tilt = rng.randf_range(-0.10, 0.12)
	t.nose_width = rng.randf_range(0.022, 0.034)
	t.hair_height = rng.randf_range(0.02, 0.12)
	t.has_mole = rng.randf() < 0.3
	t.mole_side = 1 if rng.randf() < 0.5 else -1
	t.height = rng.randf_range(0.94, 1.06)
	return t

## A face that is nearly this one. `strength` 0..1 scales how obvious the change is.
static func variant_of(traits: FaceTraits, seed_value: int, strength: float = 0.5) -> FaceTraits:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var changed := traits.duplicate_traits()
	changed.seed = traits.seed ^ 0x5bd1e995

	match rng.randi() % 6:
		0:
			changed.eye_spacing += lerpf(0.010, 0.026, strength) * (1 if rng.randf() < 0.5 else -1)
		1:
			changed.face_width += lerpf(0.015, 0.04, strength) * (1 if rng.randf() < 0.5 else -1)
		2:
			changed.brow_thickness += lerpf(0.005, 0.012, strength)
			changed.brow_tilt = -changed.brow_tilt
		3:
			changed.hair_height += lerpf(0.04, 0.09, strength) * (1 if rng.randf() < 0.5 else -1)
		4:
			changed.has_mole = not traits.has_mole
		_:
			changed.nose_width += lerpf(0.006, 0.014, strength) * (1 if rng.randf() < 0.5 else -1)
			changed.jaw = clampf(changed.jaw + lerpf(0.08, 0.16, strength) * (1 if changed.jaw < 0.24 else -1), 0.05, 0.45)
	return changed

static func render(t: FaceTraits, size: Vector2i) -> ImageTexture:
	var w := maxi(int(size.x * RENDER_SCALE), 24)
	var h := maxi(int(size.y * RENDER_SCALE), 30)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var g := _geometry(t, w, h)
	for y in h:
		for x in w:
			img.set_pixel(x, y, _pixel(t, g, x + 0.5, y + 0.5))
	img.resize(size.x, size.y, Image.INTERPOLATE_CUBIC)
	return ImageTexture.create_from_image(img)

## Everything position-dependent, computed once per portrait.
static func _geometry(t: FaceTraits, w: int, h: int) -> Dictionary:
	var rx := w * t.face_width * 0.88
	var ry := h * t.face_height * 0.78
	var head_cy := h * 0.42
	var eye_y := head_cy - ry * 0.04 + h * t.eye_height
	return {
		"w": float(w), "h": float(h), "cx": w * 0.5, "cy": head_cy, "rx": rx, "ry": ry,
		"eye_dx": w * t.eye_spacing * 0.92, "eye_y": eye_y, "erx": w * 0.048, "ery": h * 0.018,
		"brow_y": eye_y - h * 0.04, "nose_y": head_cy + ry * 0.34,
		"mouth_y": head_cy + ry * 0.60, "mouth_w": rx * 0.38,
		"hairline": head_cy - ry * (0.50 + t.hair_height),
		"lip": t.skin.lerp(Color(0.66, 0.30, 0.32), 0.42),
		"light": Vector3(-0.45, -0.55, 0.70).normalized(),
	}

static func _hash(x: float, y: float, seed_value: int) -> float:
	var n: int = (int(x) * 374761393 + int(y) * 668265263 + seed_value * 1442695041) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 2000) / 1000.0 - 1.0

static func _lambert(nx: float, ny: float, light: Vector3) -> float:
	var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
	return clampf(Vector3(nx, ny, nz).dot(light), 0.0, 1.0)

static func _pixel(t: FaceTraits, g: Dictionary, x: float, y: float) -> Color:
	var cx: float = g["cx"]
	var cy: float = g["cy"]
	var rx: float = g["rx"]
	var ry: float = g["ry"]
	var h: float = g["h"]
	var w: float = g["w"]
	var light: Vector3 = g["light"]
	var dx := x - cx
	var dy := y - cy
	var grain := _hash(x, y, t.seed) * 0.02

	# Face outline: an egg that narrows toward the jaw.
	var ny := dy / ry
	var taper := 1.0 - t.jaw * maxf(ny, 0.0) * maxf(ny, 0.0)
	var nx := dx / (rx * taper)
	var in_face := nx * nx + ny * ny <= 1.0

	# Glasses frames sit in front of everything on the face.
	var in_lens := false
	if t.glasses:
		var frame := _glasses(g, dx, y)
		if frame == 1:
			return Color(0.10, 0.09, 0.09)
		in_lens = frame == 2

	# Hair in front of the forehead.
	var hair := _front_hair(t, g, dx, dy, x, y, in_face)
	if hair.a > 0.0:
		return hair

	if in_face:
		var eye := _eye(t, g, dx, y)
		if eye.a > 0.0:
			return _through_lens(eye, in_lens)
		var brow := _brow(t, g, dx, y)
		if brow.a > 0.0:
			return _through_lens(t.skin.lerp(t.hair.darkened(0.15), brow.a), in_lens)
		var beard := _facial_hair(t, g, dx, y, ny)
		var mouth := _mouth(g, dx, y)
		if mouth.a > 0.0 and beard.a < 0.9:
			return mouth
		if beard.a >= 0.9:
			return beard
		var skin := _skin(t, g, dx, y, nx, ny) + Color(grain, grain, grain)
		if beard.a > 0.0:
			skin = skin.lerp(t.hair.darkened(0.2), beard.a)
		return _through_lens(skin, in_lens)

	# Ears, just outside the face.
	for side in [-1.0, 1.0]:
		var ex: float = (dx - rx * 0.96 * side) / (rx * 0.15)
		var ey: float = (dy - ry * 0.06) / (ry * 0.21)
		if ex * ex + ey * ey <= 1.0:
			var rim := 0.62 + 0.2 * (1.0 - absf(ex)) + (0.08 if side < 0.0 else -0.04)
			return _warm(t.skin, rim)

	var back := _back_hair(t, g, dx, dy, x, y)

	# Clothing: sloped shoulders, a collar opening, the neck inside it.
	var chin := cy + ry * 0.92
	var sx := dx / (w * 0.64)
	var sy := (y - h * 1.08) / (h * 0.30)
	var neck_w := rx * 0.42
	var in_body := sx * sx + sy * sy <= 1.0
	var in_neck := absf(dx) < neck_w and y > cy + ry * 0.4
	var open_w := neck_w * 0.75 + maxf(y - chin - h * 0.07, 0.0) * 0.3
	var in_opening := in_body and y > chin and absf(dx) < open_w
	if (in_neck and not in_body) or (in_opening and absf(dx) < neck_w * 0.8 and y < chin + h * 0.13):
		var under := clampf((y - chin) / (h * 0.05), 0.0, 1.0)
		var side_light := 0.07 * -dx / neck_w
		return _warm(t.skin, 0.52 + 0.26 * under + side_light) + Color(grain, grain, grain)
	if in_opening:
		return t.inner * (0.80 + 0.12 * _lambert(sx, sy, light)) + Color(grain, grain, grain)

	if back.a > 0.0:
		return back

	if in_body:
		var fold := 0.04 * sin(dx * 0.35 + y * 0.12)
		var lapel := 0.8 if absf(absf(dx) - open_w) < w * 0.014 else 1.0
		return t.clothes * (0.58 + 0.48 * _lambert(sx * 0.9, sy * 0.9, light) + fold) * lapel + Color(grain, grain, grain)

	# Studio backdrop: pale blue-grey, lighter behind the head.
	var u := x / w - 0.5
	var v := y / h - 0.45
	var fall := clampf(1.0 - sqrt(u * u + v * v) * 0.55, 0.0, 1.0)
	return Color(0.66, 0.71, 0.77) * (0.82 + 0.2 * fall) + Color(grain, grain, grain) * 0.5

static func _through_lens(c: Color, in_lens: bool) -> Color:
	return c.lerp(Color(0.86, 0.90, 0.95), 0.07) if in_lens else c

static func _skin(t: FaceTraits, g: Dictionary, dx: float, y: float, nx: float, ny: float) -> Color:
	var lit := _lambert(nx, ny, g["light"])
	var shade := 0.50 + 0.58 * lit
	var w: float = g["w"]
	var h: float = g["h"]
	var eye_y: float = g["eye_y"]
	var nose_y: float = g["nose_y"]
	var nw := w * t.nose_width

	# Eye sockets and the crease above each lid.
	for side in [-1.0, 1.0]:
		var sx: float = (dx - g["eye_dx"] * side) / (g["erx"] * 1.7)
		var sy: float = (y - (eye_y - g["ery"] * 0.6)) / (g["ery"] * 3.2)
		var d: float = sx * sx + sy * sy
		if d <= 1.0:
			shade *= 0.84 + 0.16 * d
		var cx2: float = (dx - g["eye_dx"] * side) / (g["erx"] * 1.05)
		var cy2: float = (y - (eye_y - g["ery"] * 1.7)) / (g["ery"] * 0.35)
		if cx2 * cx2 + cy2 * cy2 <= 1.0:
			shade *= 0.86

	# Nose: lit left flank, shadowed right flank, a rounded tip and wings.
	var ridge_top: float = eye_y + g["ery"] * 0.5
	if y > ridge_top and y < nose_y:
		var k := (y - ridge_top) / (nose_y - ridge_top)
		var half := lerpf(w * 0.012, nw * 0.8, k)
		if dx > -half * 0.2 and dx < half * 1.6:
			shade *= 1.0 - 0.16 * (1.0 - absf(dx - half * 0.7) / (half * 0.9)) * k
		elif dx < -half * 0.2 and dx > -half * 1.1:
			shade *= 1.0 + 0.05 * k
	var tip := Vector2(dx, (y - (nose_y - h * 0.006)) * 1.3)
	var tip_r := nw * 0.7
	if tip.length() < tip_r:
		shade *= 1.0 + 0.10 * (1.0 - tip.length() / tip_r) - 0.08 * clampf(dx / tip_r, 0.0, 1.0)
	for side in [-1.0, 1.0]:
		var ax: float = (dx - nw * 0.95 * side) / (nw * 0.45)
		var ay: float = (y - (nose_y - h * 0.002)) / (h * 0.012)
		var ad := ax * ax + ay * ay
		if ad <= 1.0:
			shade *= 0.90 + 0.08 * ad + (0.03 if side < 0.0 else -0.03)
	if y > nose_y + h * 0.006 and y < nose_y + h * 0.02 and absf(dx) < nw * 1.1:
		shade *= 0.84 + 0.1 * (y - nose_y) / (h * 0.02)

	# Nostrils.
	for side in [-1.0, 1.0]:
		var ox: float = (dx - nw * 0.55 * side) / (w * 0.012)
		var oy: float = (y - (nose_y + h * 0.004)) / (h * 0.0055)
		if ox * ox + oy * oy <= 1.0:
			return _warm(t.skin, 0.36)

	# Philtrum and the shadow under the lower lip.
	var mouth_y: float = g["mouth_y"]
	if absf(dx) < w * 0.012 and y > nose_y + h * 0.02 and y < mouth_y - h * 0.012:
		shade *= 0.93
	if y > mouth_y + h * 0.018 and y < mouth_y + h * 0.032 and absf(dx) < g["mouth_w"] * 0.8:
		shade *= 0.88

	# Cheeks carry a little warmth; the jaw edge falls off into shadow.
	var cheek := 0.0
	for side in [-1.0, 1.0]:
		var qx: float = (dx - g["rx"] * 0.52 * side) / (g["rx"] * 0.32)
		var qy: float = (y - (nose_y - h * 0.005)) / (h * 0.05)
		cheek = maxf(cheek, 1.0 - (qx * qx + qy * qy))

	if t.has_mole:
		var mx: float = dx - g["rx"] * 0.5 * t.mole_side
		var my: float = y - (g["cy"] + g["ry"] * 0.32)
		if mx * mx + my * my < pow(w * 0.013, 2):
			return Color(0.26, 0.17, 0.13)

	var c := _warm(t.skin, shade)
	if cheek > 0.0:
		c = c.lerp(Color(0.78, 0.42, 0.40) * shade, cheek * 0.10)
	c.a = 1.0
	return c

## Skin in shadow goes warmer and redder, not just darker.
static func _warm(skin: Color, shade: float) -> Color:
	var c := skin * shade
	if shade < 1.0:
		var s := (1.0 - shade) * 0.35
		c = Color(c.r * (1.0 + s * 0.3), c.g * (1.0 - s * 0.25), c.b * (1.0 - s * 0.35))
	c.a = 1.0
	return c

static func _eye(t: FaceTraits, g: Dictionary, dx: float, y: float) -> Color:
	var erx: float = g["erx"]
	var ery: float = g["ery"]
	for side in [-1.0, 1.0]:
		var ex: float = dx - g["eye_dx"] * side
		var ey: float = y - g["eye_y"]
		var a := ex / erx
		if absf(a) >= 1.0:
			continue
		var half := ery * sqrt(1.0 - a * a)
		# Lash line along the upper lid.
		if ey < -half and ey > -half - 1.2:
			return t.hair.darkened(0.35)
		if absf(ey) >= half:
			continue
		var ir := ery * 1.05
		var d2 := ex * ex + ey * ey
		if (ex + ir * 0.35) * (ex + ir * 0.35) + (ey + ir * 0.35) * (ey + ir * 0.35) < ir * ir * 0.05:
			return Color(0.95, 0.95, 0.95)
		if d2 < ir * ir * 0.2:
			return Color(0.04, 0.03, 0.03)
		if d2 < ir * ir:
			return t.eyes * (0.75 if ey < 0.0 else 1.0)
		# Sclera, shaded by the lid above it.
		return Color(0.86, 0.84, 0.80) * (0.72 + 0.16 * (1.0 - absf(a)) + 0.08 * clampf(ey / half, 0.0, 1.0))
	return Color(0, 0, 0, 0)

static func _brow(t: FaceTraits, g: Dictionary, dx: float, y: float) -> Color:
	var bw: float = g["erx"] * 1.25
	var h: float = g["h"]
	for side in [-1.0, 1.0]:
		var bx: float = dx - g["eye_dx"] * side
		if absf(bx) >= bw:
			continue
		var along: float = bx * side / bw
		var centre: float = g["brow_y"] - h * 0.007 * (1.0 - along * along) - t.brow_tilt * along * h * 0.02
		var thick: float = h * t.brow_thickness * 0.5 * (1.0 - 0.45 * maxf(along, 0.0))
		var dist: float = absf(y - centre)
		if dist < thick:
			return Color(0, 0, 0, clampf(1.0 - dist / thick * 0.4, 0.0, 1.0) * 0.92)
	return Color(0, 0, 0, 0)

static func _mouth(g: Dictionary, dx: float, y: float) -> Color:
	var mw: float = g["mouth_w"]
	if absf(dx) >= mw:
		return Color(0, 0, 0, 0)
	var h: float = g["h"]
	var lip: Color = g["lip"]
	var k := 1.0 - (dx / mw) * (dx / mw)
	var my: float = y - g["mouth_y"]
	# Upper lip dips at the centre (cupid's bow); the lower lip is fuller and catches light.
	var bow := h * 0.004 * clampf(1.0 - absf(dx) / (mw * 0.25), 0.0, 1.0)
	if absf(my) < 0.7:
		return lip.darkened(0.6)
	if my < 0.0 and my > -(h * 0.015 * sqrt(k)) + bow:
		return lip.darkened(0.22 - 0.1 * (-my / (h * 0.015)))
	var lower := h * 0.02 * sqrt(k)
	if my > 0.0 and my < lower:
		var f := my / lower
		return lip * (1.02 + 0.1 * (1.0 - absf(f - 0.35) * 2.0) - 0.22 * f * f - 0.06 * dx / mw)
	return Color(0, 0, 0, 0)

## Returns alpha 1 for full hair (beard), fractional for stubble, 0 for none.
static func _facial_hair(t: FaceTraits, g: Dictionary, dx: float, y: float, ny: float) -> Color:
	if t.facial_hair == FacialHair.NONE:
		return Color(0, 0, 0, 0)
	var h: float = g["h"]
	var noise := _hash(dx * 2.0, y * 2.0, t.seed + 7)
	var my: float = y - g["mouth_y"]
	var mw: float = g["mouth_w"]
	var tache := my < -h * 0.010 and my > -h * 0.026 and absf(dx) < mw * 1.15
	match t.facial_hair:
		FacialHair.STUBBLE:
			if ny > 0.22:
				return Color(0, 0, 0, (0.16 + 0.10 * noise) * clampf((ny - 0.22) / 0.2, 0.0, 1.0))
		FacialHair.MOUSTACHE:
			if tache:
				return Color(t.hair.r, t.hair.g, t.hair.b, 1.0) * (0.85 + 0.15 * noise)
		FacialHair.BEARD:
			if tache or (ny > 0.42 and not (absf(my) < h * 0.02 and absf(dx) < mw)):
				var c := t.hair * (0.80 + 0.2 * noise)
				c.a = 1.0
				return c
	return Color(0, 0, 0, 0)

static func _hair_colour(t: FaceTraits, x: float, y: float, dx: float, rx: float) -> Color:
	var streak := _hash(x, floor(y * 0.3), t.seed + 11) * 0.08
	var sheen := 0.12 * clampf(1.0 - absf(dx / rx + 0.35) * 1.6, 0.0, 1.0)
	var c := t.hair * (0.82 + sheen + streak) + Color(sheen, sheen, sheen) * 0.25
	c.a = 1.0
	return c

static func _front_hair(t: FaceTraits, g: Dictionary, dx: float, dy: float, x: float, y: float, in_face: bool) -> Color:
	var rx: float = g["rx"]
	var ry: float = g["ry"]
	var wide := 1.07
	var tall := 1.0
	if t.hair_style == Hair.BUZZ:
		wide = 1.015
		tall = 0.95
	elif t.hair_style == Hair.BUN:
		wide = 1.04
	var cap_x := dx / (rx * wide)
	var cap_y := (dy + ry * 0.12) / (ry * tall)
	var in_cap := cap_x * cap_x + cap_y * cap_y <= 1.0 and dy < ry * 0.05

	if t.hair_style == Hair.BUN:
		var bx := dx - rx * 0.05
		var by := dy + ry * 1.05
		if bx * bx + by * by < pow(rx * 0.36, 2):
			return _hair_colour(t, x, y, dx, rx)

	if not in_cap:
		return Color(0, 0, 0, 0)

	var hairline: float = g["hairline"] + ry * 0.18 * (dx / rx) * (dx / rx) 		+ ry * 0.025 * _hash(floor(x * 0.5), 0.0, t.seed + 5)
	if t.hair_style == Hair.SIDE_PART:
		hairline += ry * 0.12 * clampf(dx / rx + 0.3, -1.0, 1.0)
	if t.hair_style == Hair.BUZZ:
		hairline -= ry * 0.05
	if in_face and y >= hairline:
		return Color(0, 0, 0, 0)

	var c := _hair_colour(t, x, y, dx, rx)
	if t.hair_style == Hair.BUZZ:
		c = t.skin.lerp(t.hair, 0.55 + 0.1 * _hash(x, y, t.seed + 3))
		c.a = 1.0
	return c

static func _back_hair(t: FaceTraits, g: Dictionary, dx: float, dy: float, x: float, y: float) -> Color:
	if t.hair_style != Hair.LONG:
		return Color(0, 0, 0, 0)
	var rx: float = g["rx"]
	var ry: float = g["ry"]
	var bx := dx / (rx * 1.28)
	var by := (dy - ry * 0.35) / (ry * 1.4)
	if bx * bx + by * by <= 1.0:
		return _hair_colour(t, x, y, dx, rx) * 0.9
	return Color(0, 0, 0, 0)

## 0 = not glasses, 1 = frame, 2 = inside a lens.
static func _glasses(g: Dictionary, dx: float, y: float) -> int:
	var erx: float = g["erx"]
	var ery: float = g["ery"]
	var half_w := erx * 1.55
	var half_h := ery * 2.5
	var t := 1.1
	var ey: float = y - (g["eye_y"] + ery * 0.4)
	for side in [-1.0, 1.0]:
		var ex: float = dx - g["eye_dx"] * side
		if absf(ex) <= half_w and absf(ey) <= half_h:
			if absf(ex) > half_w - t or absf(ey) > half_h - t:
				return 1
			return 2
	var inner: float = g["eye_dx"] - half_w
	if absf(dx) < inner and absf(ey + ery * 0.6) < 0.7:
		return 1
	return 0
