extends RefCounted

var _path := ""
var _write_allowed := true


func configure(path: String) -> void:
	_path = path
	_write_allowed = true


func load_data(backup_before_version: int = 0) -> Dictionary:
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return {}
	var file := FileAccess.open(_path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	if int(parsed.get("saveVersion", 1)) < backup_before_version:
		var backup_path := "%s.pre-v%d.bak" % [_path, backup_before_version]
		if not FileAccess.file_exists(backup_path):
			var result := DirAccess.copy_absolute(ProjectSettings.globalize_path(_path), ProjectSettings.globalize_path(backup_path))
			_write_allowed = result == OK
			if not _write_allowed:
				push_error("Save migration backup failed; the original save will not be overwritten.")
	return parsed


func save_data(data: Dictionary) -> bool:
	if _path.is_empty() or not _write_allowed:
		return false
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	return true
