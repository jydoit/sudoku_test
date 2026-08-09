extends RefCounted

var _path := ""


func configure(path: String) -> void:
	_path = path


func load_data() -> Dictionary:
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return {}
	var file := FileAccess.open(_path, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func save_data(data: Dictionary) -> bool:
	if _path.is_empty():
		return false
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	return true
