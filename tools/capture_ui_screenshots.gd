extends SceneTree

const SAVE_PATH := "user://color_queens_save.json"
const OUTPUT_PREFIX := "/private/tmp/color_king_ui_"

var game


func _init() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate()
	root.add_child(game)
	await _settle()

	game.localization.set_locale("zh")
	await _settle()
	await _shot("01_tutorial")
	game._cancel_opening_king_intro()
	game._on_cell_double_pressed(2, 2)
	await _settle()
	await _shot("01_tutorial_drag")

	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	game._show_home()
	await _settle()
	await _shot("02_home")

	game.player_level_number = 1
	game.current_level_index = 0
	var schedule: Dictionary = game._schedule_for_current_level()
	game._load_level(int(schedule.get("levelIndex", 0)), true, schedule)
	game._show_game()
	await _settle()
	game._cancel_opening_king_intro()
	await _settle()
	await _shot("03_level")

	var mark_cell := _first_empty_non_solution_cell()
	var piece_cell := _first_empty_solution_cell()
	var wrong_cell := _next_empty_non_solution_cell(mark_cell)
	game.cell_states[mark_cell.y][mark_cell.x] = "blocked"
	game.cell_states[piece_cell.y][piece_cell.x] = "piece"
	game.cell_states[wrong_cell.y][wrong_cell.x] = "wrong"
	game.board.set_states(game.cell_states)
	await _settle()
	await _shot("03_board_marks")

	game._load_level(int(schedule.get("levelIndex", 0)), true, schedule)
	game._show_game()
	game._cancel_opening_king_intro()
	await _settle()
	game._open_level_select()
	await _settle()
	await _shot("04_level_select")
	game.dialog_controller.hide_dialog(true)
	await _settle()
	game._use_hint()
	await _settle()
	await _shot("04_hint")

	game.localization.set_locale("zh")
	game._on_settings()
	await _settle()
	await _shot("04_dialog_zh")
	game.dialog_controller.hide_dialog(true)
	game.localization.set_locale("en")
	game._on_settings()
	await _settle()
	await _shot("04_dialog_en")
	game.dialog_controller.hide_dialog(true)
	game.localization.set_locale("ar")
	game._on_settings()
	await _settle()
	await _shot("04_dialog_ar")
	game.dialog_controller.hide_dialog(true)
	game.localization.set_locale("zh")
	await _settle()

	for coordinate in game.current_level["solution"]:
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		if not game._is_king_cell(row, col):
			game.cell_states[row][col] = "piece"
	game.board.set_states(game.cell_states)
	game._validate_and_update(true)
	await _settle()
	await create_timer(0.65).timeout
	await _settle()
	await _shot("05_success")

	game._replay_level()
	await _settle()
	var wrong_cells: Array[Vector2i] = []
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col) or game._is_solution_cell(row, col):
				continue
			wrong_cells.append(Vector2i(col, row))
			if wrong_cells.size() >= game.current_heart_limit:
				break
		if wrong_cells.size() >= game.current_heart_limit:
			break
	for cell in wrong_cells:
		game._on_cell_double_pressed(cell.y, cell.x)
		await _settle()
	await create_timer(2.15).timeout
	await _settle()
	await _shot("06_failure")
	quit()


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("%s%s.png" % [OUTPUT_PREFIX, name])


func _first_empty_solution_cell() -> Vector2i:
	for coordinate in game.current_level["solution"]:
		var cell := Vector2i(int(coordinate[1]), int(coordinate[0]))
		if not game._is_king_cell(cell.y, cell.x) and str(game.cell_states[cell.y][cell.x]) == "empty":
			return cell
	return Vector2i(-1, -1)


func _first_empty_non_solution_cell() -> Vector2i:
	return _next_empty_non_solution_cell(Vector2i(-1, -1))


func _next_empty_non_solution_cell(excluded: Vector2i) -> Vector2i:
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			var cell := Vector2i(col, row)
			if cell != excluded and not game._is_king_cell(row, col) and not game._is_solution_cell(row, col):
				return cell
	return Vector2i(-1, -1)
