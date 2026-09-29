extends SceneTree

## Reads every playtest log in a folder and writes a balance report.
## Run: godot --headless --path <project> --script res://tools/playtest_report.gd -- <logs_dir> [report.md]
## With no folder it reads this machine's own logs (user://playtest).

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if args.size() > 0 else "user://playtest"
	var out := args[1] if args.size() > 1 else folder.path_join("report.md")

	var sessions: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("No such folder: %s" % folder)
		quit(1)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file_name)))
		if parsed is Dictionary and parsed.has("shifts"):
			sessions.append(parsed)
		else:
			print("skipped %s (not a playtest log)" % file_name)

	var report := PlaytestAnalysis.to_markdown(PlaytestAnalysis.summarise(sessions))
	print(report)
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file:
		file.store_string(report)
		print("written to %s" % ProjectSettings.globalize_path(out))
	quit()
