extends RefCounted

const SVG_PATH := "res://assets/ui/coin.svg"

static var _cached_texture: Texture2D


static func texture() -> Texture2D:
	if _cached_texture:
		return _cached_texture
	var imported_texture := load(SVG_PATH)
	if imported_texture is Texture2D:
		_cached_texture = imported_texture
		return _cached_texture
	if not FileAccess.file_exists(SVG_PATH):
		return null
	var svg_text := FileAccess.get_file_as_string(SVG_PATH)
	if svg_text.is_empty():
		return null
	var image := Image.new()
	var error := image.load_svg_from_string(svg_text, 1.0)
	if error != OK:
		return null
	_cached_texture = ImageTexture.create_from_image(image)
	return _cached_texture
