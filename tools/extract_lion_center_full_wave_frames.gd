extends SceneTree

## Converts the image-model source sheet into complete registered lion frames.
## Each runtime PNG contains one fully baked lion; no body/arm compositing occurs.

const SOURCE_PATH := "res://docs/animation_sources/lion_center_full_wave_model_sheet.png"
const OUTPUT_TEMPLATE := "res://assets/ui/lion_king_center_full_wave_%02d.png"
const CANVAS_SIZE := Vector2i(400, 400)
const DESTINATION_CROWN_X := 200
const DESTINATION_TOP_Y := 22

# Each crop includes two pixels of safety margin. Registration uses the crown
# centre rather than the changing silhouette bounds so the fixed body does not
# drift as the waving paw travels horizontally.
const FRAME_SPECS := [
	{"rect": Rect2i(30, 228, 245, 356), "crown_x": 131.5},
	{"rect": Rect2i(300, 228, 253, 356), "crown_x": 139.5},
	{"rect": Rect2i(567, 229, 262, 355), "crown_x": 149.25},
	{"rect": Rect2i(847, 229, 256, 355), "crown_x": 144.4},
	{"rect": Rect2i(1109, 229, 255, 355), "crown_x": 144.71},
	{"rect": Rect2i(1371, 229, 253, 355), "crown_x": 143.5},
	{"rect": Rect2i(1634, 229, 250, 355), "crown_x": 141.15},
]


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source.is_empty():
		push_error("Unable to load full-lion wave source sheet: %s" % SOURCE_PATH)
		quit(1)
		return

	for frame_index in range(FRAME_SPECS.size()):
		var spec: Dictionary = FRAME_SPECS[frame_index]
		var frame := _extract_complete_lion(source, spec["rect"])
		var canvas := Image.create_empty(
			CANVAS_SIZE.x,
			CANVAS_SIZE.y,
			false,
			Image.FORMAT_RGBA8
		)
		canvas.fill(Color.TRANSPARENT)
		var destination := Vector2i(
			DESTINATION_CROWN_X - roundi(float(spec["crown_x"])),
			DESTINATION_TOP_Y
		)
		canvas.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), destination)

		var output_path := OUTPUT_TEMPLATE % frame_index
		var error := canvas.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("Unable to save complete lion wave frame %s: %s" % [output_path, error])
			quit(1)
			return

	print("Generated %d complete registered lion wave frames." % FRAME_SPECS.size())
	quit()


func _extract_complete_lion(source: Image, source_rect: Rect2i) -> Image:
	var frame := Image.create_empty(
		source_rect.size.x,
		source_rect.size.y,
		false,
		Image.FORMAT_RGBA8
	)
	frame.fill(Color.TRANSPARENT)
	for y in range(source_rect.size.y):
		for x in range(source_rect.size.x):
			var color := source.get_pixel(source_rect.position.x + x, source_rect.position.y + y)
			var minimum := minf(color.r, minf(color.g, color.b))
			var maximum := maxf(color.r, maxf(color.g, color.b))
			var chroma := maximum - minimum
			# The generator returned a near-white RGB backdrop. Keep all warm
			# character colours and dark outlines while removing only neutral white.
			if minimum > 0.91 and chroma < 0.06:
				continue
			color.a = 1.0
			frame.set_pixel(x, y, color)
	return frame
