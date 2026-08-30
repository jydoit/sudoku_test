extends SceneTree

const HomePageScript = preload("res://scripts/pages/home_page.gd")


func _init() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_capture")


func _capture() -> void:
	var home = HomePageScript.new()
	root.add_child(home)
	home.configure()
	home.present({
		"tutorial_completed": true,
		"player_level": 11,
		"composite_unlocked": true,
	})
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("/private/tmp/color_king_home_brand.png")
	quit()
