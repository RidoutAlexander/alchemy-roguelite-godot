class_name SaveService
extends RefCounted


static func save_path() -> String:
	return ProjectSettings.globalize_path("user://") + GameConstants.SAVE_FILE_NAME


static func has_save() -> bool:
	return FileAccess.file_exists("user://" + GameConstants.SAVE_FILE_NAME)


static func load_run() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open("user://" + GameConstants.SAVE_FILE_NAME, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func save_run(data: Dictionary) -> void:
	data["hasActiveRun"] = true
	var file := FileAccess.open("user://" + GameConstants.SAVE_FILE_NAME, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute("user://" + GameConstants.SAVE_FILE_NAME)