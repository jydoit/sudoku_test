extends SceneTree

## Extracts the model-authored two-handed coin toss into complete registered
## runtime frames. The pale checkerboard is connected RGB artwork rather than
## real alpha, so only neutral pixels reachable from each crop edge are removed.

const SOURCE_PATH := "res://docs/animation_sources/lion_center_coin_toss_model_sheet.png"
const OUTPUT_TEMPLATE := "res://assets/ui/lion_king_center_coin_toss_%02d.png"
const CANVAS_SIZE := Vector2i(400, 400)
const SOURCE_TOP := 255
const SOURCE_HEIGHT := 400
const DESTINATION_CROWN := Vector2i(200, 22)
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

const FRAME_SPECS := [
	{"left": 0, "right": 285, "crown_x": 156, "crown_y": 275},
	{"left": 285, "right": 570, "crown_x": 435, "crown_y": 275},
	{"left": 570, "right": 856, "crown_x": 711, "crown_y": 275},
	{"left": 830, "right": 1145, "crown_x": 996, "crown_y": 275},
	{"left": 1135, "right": 1430, "crown_x": 1283, "crown_y": 275},
	{"left": 1390, "right": 1730, "crown_x": 1564, "crown_y": 275},
	{"left": 1712, "right": 1997, "crown_x": 1845, "crown_y": 275},
]


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source.is_empty():
		push_error("Unable to load two-handed coin toss source sheet: %s" % SOURCE_PATH)
		quit(1)
		return

	for frame_index in range(FRAME_SPECS.size()):
		var spec: Dictionary = FRAME_SPECS[frame_index]
		var source_rect := Rect2i(
			int(spec["left"]),
			SOURCE_TOP,
			int(spec["right"]) - int(spec["left"]),
			SOURCE_HEIGHT
		)
		var frame := source.get_region(source_rect)
		_clear_connected_neutral_background(frame)
		_keep_character_and_coin_pile(frame, frame_index, int(spec["crown_x"]) - source_rect.position.x)
		var canvas := Image.create_empty(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var crown_in_crop := Vector2i(
			int(spec["crown_x"]) - source_rect.position.x,
			int(spec["crown_y"]) - source_rect.position.y
		)
		var destination := DESTINATION_CROWN - crown_in_crop
		canvas.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), destination)

		var output_path := OUTPUT_TEMPLATE % frame_index
		var error := canvas.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("Unable to save complete coin toss frame %s: %s" % [output_path, error])
			quit(1)
			return

	print("Generated %d complete registered two-handed coin toss frames." % FRAME_SPECS.size())
	quit()


func _clear_connected_neutral_background(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()

	for x in range(width):
		_try_queue_background(image, x, 0, width, height, visited, queue)
		_try_queue_background(image, x, height - 1, width, height, visited, queue)
	for y in range(1, height - 1):
		_try_queue_background(image, 0, y, width, height, visited, queue)
		_try_queue_background(image, width - 1, y, width, height, visited, queue)

	var cursor := 0
	while cursor < queue.size():
		var packed_index := queue[cursor]
		cursor += 1
		var x := packed_index % width
		var y := floori(float(packed_index) / float(width))
		image.set_pixel(x, y, Color.TRANSPARENT)
		_try_queue_background(image, x - 1, y, width, height, visited, queue)
		_try_queue_background(image, x + 1, y, width, height, visited, queue)
		_try_queue_background(image, x, y - 1, width, height, visited, queue)
		_try_queue_background(image, x, y + 1, width, height, visited, queue)


func _try_queue_background(
	image: Image,
	x: int,
	y: int,
	width: int,
	height: int,
	visited: PackedByteArray,
	queue: PackedInt32Array
) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	var packed_index := y * width + x
	if visited[packed_index] != 0:
		return
	visited[packed_index] = 1
	if _is_neutral_background(image.get_pixel(x, y)):
		queue.append(packed_index)


func _is_neutral_background(color: Color) -> bool:
	var minimum := minf(color.r, minf(color.g, color.b))
	var maximum := maxf(color.r, maxf(color.g, color.b))
	return minimum > 0.70 and maximum - minimum < 0.065


func _keep_character_and_coin_pile(image: Image, frame_index: int, crown_x: int) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var components: Array[PackedInt32Array] = []

	for y in range(height):
		for x in range(width):
			var packed_index := y * width + x
			if visited[packed_index] != 0 or image.get_pixel(x, y).a <= 0.01:
				continue
			var component := _collect_foreground_component(image, x, y, visited)
			components.append(component)

	if components.is_empty():
		return
	var largest_index := 0
	for component_index in range(1, components.size()):
		if components[component_index].size() > components[largest_index].size():
			largest_index = component_index

	for component_index in range(components.size()):
		var component := components[component_index]
		var keep := component_index == largest_index
		if not keep and frame_index <= 2:
			keep = _is_loose_coin_pile_component(image, component, crown_x)
		if keep:
			continue
		for packed_index in component:
			var x := packed_index % width
			var y := floori(float(packed_index) / float(width))
			image.set_pixel(x, y, Color.TRANSPARENT)


func _collect_foreground_component(
	image: Image,
	start_x: int,
	start_y: int,
	visited: PackedByteArray
) -> PackedInt32Array:
	var width := image.get_width()
	var height := image.get_height()
	var component := PackedInt32Array()
	var queue := PackedInt32Array([start_y * width + start_x])
	visited[start_y * width + start_x] = 1
	var cursor := 0
	while cursor < queue.size():
		var packed_index := queue[cursor]
		cursor += 1
		component.append(packed_index)
		var x := packed_index % width
		var y := floori(float(packed_index) / float(width))
		for offset: Vector2i in NEIGHBOR_OFFSETS:
			var neighbor_x: int = x + offset.x
			var neighbor_y: int = y + offset.y
			if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
				continue
			var neighbor_index: int = neighbor_y * width + neighbor_x
			if visited[neighbor_index] != 0:
				continue
			visited[neighbor_index] = 1
			if image.get_pixel(neighbor_x, neighbor_y).a > 0.01:
				queue.append(neighbor_index)
	return component


func _is_loose_coin_pile_component(
	image: Image,
	component: PackedInt32Array,
	crown_x: int
) -> bool:
	if component.size() > 1400:
		return false
	var width := image.get_width()
	var center_x_total := 0.0
	var center_y_total := 0.0
	var contains_gold := false
	for packed_index in component:
		var x := packed_index % width
		var y := floori(float(packed_index) / float(width))
		center_x_total += float(x)
		center_y_total += float(y)
		var color := image.get_pixel(x, y)
		if color.r > 0.72 and color.g > 0.28 and color.g < 0.88 and color.b < 0.28:
			contains_gold = true
	var center_x := center_x_total / float(component.size())
	var center_y := center_y_total / float(component.size())
	return contains_gold and absf(center_x - float(crown_x)) <= 105.0 and center_y >= 145.0
