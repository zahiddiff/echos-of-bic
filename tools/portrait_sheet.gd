extends SceneTree

## Writes a contact sheet of generated ID photos, and times them.
## Run: godot --headless --path <project> --script res://tools/portrait_sheet.gd

func _init() -> void:
	var size := Vector2i(240, 300)
	var sheet := Image.create(size.x * 6, size.y * 3, false, Image.FORMAT_RGB8)
	var start := Time.get_ticks_msec()
	for i in 12:
		var face := PortraitFactory.traits_for(1000 + i * 7919)
		var img := PortraitFactory.render(face, size).get_image()
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i((i % 6) * size.x, (i / 6) * size.y))
	var per := (Time.get_ticks_msec() - start) / 12.0
	for i in 6:
		var face := PortraitFactory.traits_for(5000 + i / 2)
		var twin := PortraitFactory.variant_of(face, 77 + i / 2, 0.5)
		var img := PortraitFactory.render(face if i % 2 == 0 else twin, size).get_image()
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i(i * size.x, 2 * size.y))
	sheet.save_png(OS.get_environment("SHEET_OUT") if OS.has_environment("SHEET_OUT") else "user://portraits.png")
	print("%.1f ms per portrait" % per)
	quit()
