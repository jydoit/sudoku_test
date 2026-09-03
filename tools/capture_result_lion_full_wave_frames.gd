extends SceneTree

const OUTPUT_PATH := "/private/tmp/color_king_result_lion_full_wave_frames.png"
const FRAMES: Array[Texture2D] = [
	preload("res://assets/ui/lion_king_center_full_wave_00.png"),
	preload("res://assets/ui/lion_king_center_full_wave_01.png"),
	preload("res://assets/ui/lion_king_center_full_wave_02.png"),
	preload("res://assets/ui/lion_king_center_full_wave_03.png"),
	preload("res://assets/ui/lion_king_center_full_wave_04.png"),
	preload("res://assets/ui/lion_king_center_full_wave_05.png"),
	preload("res://assets/ui/lion_king_center_full_wave_06.png"),
]


func _init() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")


func _run() -> void:
	var background := ColorRect.new()
	background.color = Color("#EAF4FF")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	for index in range(FRAMES.size()):
		var card := ColorRect.new()
		card.color = Color.WHITE
		card.position = Vector2(index % 3 * 180, 120 + index / 3 * 240)
		card.size = Vector2(180, 220)
		background.add_child(card)

		var lion := TextureRect.new()
		lion.texture = FRAMES[index]
		lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lion.position = Vector2(10, 30)
		lion.size = Vector2(160, 160)
		card.add_child(lion)

	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUTPUT_PATH)
	quit()
