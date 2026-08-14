extends Control

const LevelStoreScript = preload("res://scripts/level_store.gd")
const GameBoardScript = preload("res://scripts/game_board.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")
const CoinEconomyScript = preload("res://scripts/coin_economy.gd")
const CoinRewardPolicyScript = preload("res://scripts/coin_reward_policy.gd")
const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const UITokensScript = preload("res://scripts/ui_tokens.gd")
const DialogControllerScript = preload("res://scripts/dialog_controller.gd")
const LocalizationControllerScript = preload("res://scripts/localization_controller.gd")
const AudioControllerScript = preload("res://scripts/audio_controller.gd")
const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const CompositeLevelStoreScript = preload("res://scripts/composite_level_store.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const AssemblyViewScript = preload("res://scripts/assembly_view.gd")
const HomePageScript = preload("res://scripts/pages/home_page.gd")
const FormalLevelPageScript = preload("res://scripts/pages/formal_level_page.gd")
const CompositeLevelPageScript = preload("res://scripts/pages/composite_level_page.gd")
const ResultPageScript = preload("res://scripts/pages/result_page.gd")
const HelpDialogContentScript = preload("res://scripts/dialogs/help_dialog_content.gd")
const LEVEL_SELECT_DIALOG_PATH := "res://scripts/dialogs/level_select_dialog_content.gd"
const SettingsDialogContentScript = preload("res://scripts/dialogs/settings_dialog_content.gd")
const OpeningKingOverlayScript = preload("res://scripts/overlays/opening_king_overlay.gd")
const TutorialOverlayScript = preload("res://scripts/overlays/tutorial_overlay.gd")
const FeedbackLayerScript = preload("res://scripts/overlays/feedback_layer.gd")
const TutorialControllerScript = preload("res://scripts/controllers/tutorial_controller.gd")
const CompositeGameControllerScript = preload("res://scripts/controllers/composite_game_controller.gd")
const SaveRepositoryScript = preload("res://scripts/storage/save_repository.gd")
const HintEngineScript = preload("res://scripts/controllers/hint_engine.gd")
const CrownRuleEngineScript = preload("res://scripts/rules/crown_rule_engine.gd")
const CompositePlacementEngineScript = preload("res://scripts/rules/composite_placement_engine.gd")
const FormalGameControllerScript = preload("res://scripts/controllers/formal_game_controller.gd")
const PlayerWalletScript = preload("res://scripts/services/player_wallet.gd")
const CompositeEntryServiceScript = preload("res://scripts/services/composite_entry_service.gd")
const GameSaveServiceScript = preload("res://scripts/storage/game_save_service.gd")
const RunResultServiceScript = preload("res://scripts/services/run_result_service.gd")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.ttf")
const ARABIC_FONT: Font = preload("res://assets/fonts/NotoSansArabic-Regular.ttf")
const LION_KING_ICON = preload("res://assets/ui/lion_king.png")
const LION_KING_WRONG_ICON = preload("res://assets/ui/lion_king_wrong.png")
const LION_KING_VICTORY_ICON = preload("res://assets/ui/lion_king_victory.png")
const LION_KING_VICTORY_OUT_ICON = preload("res://assets/ui/lion_king_victory_out.png")
const LION_KING_VICTORY_IN_ICON = preload("res://assets/ui/lion_king_victory_in.png")
const LION_KING_VICTORY_WAVE_OUT_MID_ICON = preload("res://assets/ui/lion_king_victory_wave_out_mid.png")
const LION_KING_VICTORY_WAVE_IN_MID_ICON = preload("res://assets/ui/lion_king_victory_wave_in_mid.png")
const LION_KING_VICTORY_TONGUE_PEEK_ICON = preload("res://assets/ui/lion_king_victory_tongue_peek.png")
const LION_KING_VICTORY_TONGUE_OUT_ICON = preload("res://assets/ui/lion_king_victory_tongue_out.png")
const LION_KING_VICTORY_WINK_ICON = preload("res://assets/ui/lion_king_victory_wink.png")
const LION_KING_VICTORY_FUNNY_ICON = preload("res://assets/ui/lion_king_victory_funny.png")
const LION_KING_VICTORY_FRAMES = [
	LION_KING_VICTORY_ICON,
	LION_KING_VICTORY_OUT_ICON,
	LION_KING_VICTORY_IN_ICON,
	LION_KING_VICTORY_WAVE_OUT_MID_ICON,
	LION_KING_VICTORY_WAVE_IN_MID_ICON,
	LION_KING_VICTORY_TONGUE_PEEK_ICON,
	LION_KING_VICTORY_TONGUE_OUT_ICON,
	LION_KING_VICTORY_WINK_ICON,
	LION_KING_VICTORY_FUNNY_ICON
]
const SAVE_PATH := "user://color_queens_save.json"
const SAVE_PATH_OVERRIDE_SETTING := "color_king/testing/save_path"
const SAVE_VERSION := 16
const INITIAL_COIN_COUNT := 10
const INITIAL_HINT_COUNT := 5
const INITIAL_HEART_COUNT := 3
const INITIAL_CROWN_FIND_COUNT := 3
const INK := UITokensScript.INK
const MUTED := UITokensScript.MUTED
const CREAM := UITokensScript.SURFACE_CREAM
const CARD := UITokensScript.SURFACE_CARD
const GREEN := UITokensScript.SUCCESS_GREEN
const HEART_ACTIVE_COLOR := Color("#F25D72")
const HEART_EMPTY_COLOR := Color("#C8CDD5")
const COACH_TUTORIAL_SIZE := 19
const COACH_NORMAL_SIZE := 16
const TUTORIAL_PHASE_PLACE := TutorialControllerScript.PHASE_PLACE
const TUTORIAL_PHASE_ADJACENT := TutorialControllerScript.PHASE_ADJACENT
const TUTORIAL_PHASE_ROW_COL := TutorialControllerScript.PHASE_ROW_COL
const TUTORIAL_PHASE_HINT := TutorialControllerScript.PHASE_HINT
const TUTORIAL_PHASE_HINT_PLACE := TutorialControllerScript.PHASE_HINT_PLACE
const TUTORIAL_PHASE_CROWN_FIND := TutorialControllerScript.PHASE_CROWN_FIND
const TUTORIAL_PHASE_DONE := TutorialControllerScript.PHASE_DONE
const REGION_COLOR_NAMES = UITokensScript.REGION_COLOR_NAMES
const REGION_COLORS = UITokensScript.REGION_COLORS
const TUTORIAL_LEVELS = [
	{
		"levelId": -101,
		"title": "新手教程",
		"name": "",
		"rows": 5,
		"cols": 5,
		"targetCount": 5,
		"tutorial": "每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。",
		"regions": [
			[3, 2, 2, 4, 4],
			[3, 2, 4, 4, 4],
			[3, 2, 1, 5, 5],
			[3, 3, 5, 5, 5],
			[3, 3, 5, 5, 5]
		],
		"solution": [[2, 2], [0, 1], [1, 4], [4, 3], [3, 0]],
		"target": [2, 2],
		"kind": "single_map"
	}
]

var levels: Array = []
var current_level_index := 0
var player_level_number := 1
var current_level: Dictionary = {}
var active_schedule: Dictionary = {}
var active_king_positions: Array = []
var cell_states: Array = []
var formal_controller
var move_history: Array:
	get: return formal_controller.move_history if formal_controller else []
	set(value):
		if formal_controller: formal_controller.move_history = value
var completed_levels: Array = []
var director_progress: Dictionary = {}
var composite_director_progress: Dictionary = {}
var composite_coin_progress: Dictionary = CompositeCoinPolicyScript.default_progress()
var player_wallet = PlayerWalletScript.new()
var economy_progress: Dictionary:
	get: return player_wallet.economy_progress
	set(value): player_wallet.economy_progress = value
var coin_count: int:
	get: return player_wallet.balance
	set(value): player_wallet.balance = value
var heart_count := INITIAL_HEART_COUNT
var current_heart_limit := INITIAL_HEART_COUNT
var hint_count := INITIAL_HINT_COUNT
var crown_find_count := INITIAL_CROWN_FIND_COUNT
var immediate_errors := true
var is_completed := false
var is_failed := false
var hint_engine
var run_started_unix := 0
var run_move_count := 0
var run_hint_count := 0
var run_direct_find_count := 0
var run_coin_exchange_count: int:
	get: return player_wallet.run_exchange_count
	set(value): player_wallet.run_exchange_count = value
var resume_level_id := -1
var resume_states: Array = []
var resume_completed := false
var resume_failed := false
var formal_progress_snapshot: Dictionary = {}
var home_composite_progress_snapshot: Dictionary = {}
var home_composite_history: Dictionary = {}
var home_composite_entry_active := false
var home_composite_round := 0
var composite_controller
var resume_composite_state: Dictionary:
	get: return composite_controller.resume_state if composite_controller else {}
	set(value):
		if composite_controller: composite_controller.resume_state = value
var composite_mode: bool:
	get: return composite_controller.mode if composite_controller else false
	set(value):
		if composite_controller: composite_controller.mode = value
var composite_phase: String:
	get: return composite_controller.phase if composite_controller else "crown"
	set(value):
		if composite_controller: composite_controller.phase = value
var composite_data: Dictionary:
	get: return composite_controller.data if composite_controller else {}
	set(value):
		if composite_controller: composite_controller.data = value
var composite_levels
var composite_placements: Dictionary:
	get: return composite_controller.placements if composite_controller else {}
	set(value):
		if composite_controller: composite_controller.placements = value
var composite_placement_history: Array:
	get: return composite_controller.placement_history if composite_controller else []
	set(value):
		if composite_controller: composite_controller.placement_history = value
var composite_tray_slots: Array:
	get: return composite_controller.tray_slots if composite_controller else []
	set(value):
		if composite_controller: composite_controller.tray_slots = value
var composite_deadlocked: bool:
	get: return composite_controller.deadlocked if composite_controller else false
	set(value):
		if composite_controller: composite_controller.deadlocked = value
var composite_final_layout: Dictionary:
	get: return composite_controller.final_layout if composite_controller else {}
	set(value):
		if composite_controller: composite_controller.final_layout = value
var composite_tutorial_seen: bool:
	get: return composite_controller.tutorial_seen if composite_controller else false
	set(value):
		if composite_controller: composite_controller.tutorial_seen = value
var composite_intro_running: bool:
	get: return composite_controller.intro_running if composite_controller else false
	set(value):
		if composite_controller: composite_controller.intro_running = value
var composite_intro_marks_seen: bool:
	get: return composite_controller.intro_marks_seen if composite_controller else false
	set(value):
		if composite_controller: composite_controller.intro_marks_seen = value
var tutorial_controller
var tutorial_completed: bool:
	get: return tutorial_controller.completed if tutorial_controller else false
	set(value):
		if tutorial_controller: tutorial_controller.completed = value
var tutorial_started: bool:
	get: return tutorial_controller.started if tutorial_controller else false
	set(value):
		if tutorial_controller: tutorial_controller.started = value
var tutorial_step_index: int:
	get: return tutorial_controller.step_index if tutorial_controller else 0
	set(value):
		if tutorial_controller: tutorial_controller.step_index = value
var tutorial_interaction_stage: int:
	get: return tutorial_controller.interaction_stage if tutorial_controller else TUTORIAL_PHASE_PLACE
	set(value):
		if tutorial_controller: tutorial_controller.interaction_stage = value
var tutorial_button_stage: int:
	get: return tutorial_controller.button_stage if tutorial_controller else 0
	set(value):
		if tutorial_controller: tutorial_controller.button_stage = value
var tutorial_solution_index: int:
	get: return tutorial_controller.solution_index if tutorial_controller else 0
	set(value):
		if tutorial_controller: tutorial_controller.solution_index = value
var tutorial_active_crown: Vector2i:
	get: return tutorial_controller.active_crown if tutorial_controller else Vector2i(-1, -1)
	set(value):
		if tutorial_controller: tutorial_controller.active_crown = value
var tutorial_hint_target: Vector2i:
	get: return tutorial_controller.hint_target if tutorial_controller else Vector2i(-1, -1)
	set(value):
		if tutorial_controller: tutorial_controller.hint_target = value
var tutorial_hint_button_taught: bool:
	get: return tutorial_controller.hint_button_taught if tutorial_controller else false
	set(value):
		if tutorial_controller: tutorial_controller.hint_button_taught = value
var tutorial_crown_find_taught: bool:
	get: return tutorial_controller.crown_find_taught if tutorial_controller else false
	set(value):
		if tutorial_controller: tutorial_controller.crown_find_taught = value
var in_tutorial: bool:
	get: return tutorial_controller.active if tutorial_controller else false
	set(value):
		if tutorial_controller: tutorial_controller.active = value

var home_screen: Control
var game_screen: Control
var formal_level_page
var composite_level_page
var home_start_button: Button
var home_composite_button: Button
var level_select_button: Button:
	get: return game_screen.level_select_button if game_screen else null
var settings_button: Button:
	get: return game_screen.settings_button if game_screen else null
var board:
	get: return game_screen.board if game_screen else null
var level_picker: OptionButton
var level_select_picker: OptionButton
var level_label: Label:
	get: return game_screen.level_label if game_screen else null
var help_button: Button:
	get: return game_screen.help_button if game_screen else null
var top_home_button: Button:
	get: return game_screen.top_home_button if game_screen else null
var coin_label: Label:
	get: return game_screen.coin_label if game_screen else null
var coin_balance_roll_clip: Control:
	get: return game_screen.coin_balance_roll_clip if game_screen else null
var coin_balance_roll_secondary: Label:
	get: return game_screen.coin_balance_roll_secondary if game_screen else null
var level_heart_label: Control:
	get: return game_screen.level_heart_label if game_screen else null
var level_heart_slots: Array[Label]:
	get: return game_screen.level_heart_slots if game_screen else []
var level_heart_tweens: Array:
	get: return game_screen.heart_tweens if game_screen else []
var progress_bar: ProgressBar:
	get: return game_screen.progress_bar if game_screen else null
var progress_label: Label:
	get: return game_screen.progress_label if game_screen else null
var progress_row: Control:
	get: return game_screen.progress_row if game_screen else null
var assembly_tray_target: Control:
	get: return game_screen.assembly_tray_target if game_screen else null
var action_bar: Control:
	get: return game_screen.action_bar if game_screen else null
var assembly_stage_label: Label:
	get: return game_screen.assembly_stage_label if game_screen else null
var assembly_view:
	get: return game_screen.assembly_view if game_screen else null
var coach_panel: PanelContainer:
	get: return game_screen.coach_panel if game_screen else null
var coach_label: Label:
	get: return game_screen.coach_label if game_screen else null
var opening_king_overlay: ColorRect
var opening_king_panel: PanelContainer
var opening_king_title: Label
var opening_king_count_label: Label
var opening_king_source_label: Control
var opening_king_source_count_label: Label
var undo_button: Button:
	get: return null
var clear_button: Button:
	get: return game_screen.clear_button if game_screen else null
var clear_button_label: Label:
	get: return game_screen.clear_button_label if game_screen else null
var clear_status_panel: PanelContainer:
	get: return game_screen.clear_status_panel if game_screen else null
var clear_status_icon: TextureRect:
	get: return game_screen.clear_status_icon if game_screen else null
var clear_status_label: Label:
	get: return game_screen.clear_status_label if game_screen else null
var crown_find_button: Button:
	get: return game_screen.crown_find_button if game_screen else null
var crown_find_button_label: Label:
	get: return game_screen.crown_find_button_label if game_screen else null
var crown_find_status_panel: PanelContainer:
	get: return game_screen.crown_find_status_panel if game_screen else null
var crown_find_status_icon: TextureRect:
	get: return game_screen.crown_find_status_icon if game_screen else null
var crown_find_status_label: Label:
	get: return game_screen.crown_find_status_label if game_screen else null
var hint_button: Button:
	get: return game_screen.hint_button if game_screen else null
var hint_button_label: Label:
	get: return game_screen.hint_button_label if game_screen else null
var hint_status_panel: PanelContainer:
	get: return game_screen.hint_status_panel if game_screen else null
var hint_status_icon: TextureRect:
	get: return game_screen.hint_status_icon if game_screen else null
var hint_status_label: Label:
	get: return game_screen.hint_status_label if game_screen else null
var tutorial_skip_button: Button:
	get: return game_screen.tutorial_skip_button if game_screen else null
var result_page
var completion_overlay: ColorRect:
	get: return result_page
var completion_next_button: Button:
	get: return result_page.completion_next_button if result_page else null
var completion_replay_button: Button:
	get: return result_page.completion_replay_button if result_page else null
var toast_label: Label
var tutorial_center_popup: Label
var tutorial_hand_label: Label
var tutorial_hand_control: Control:
	get: return tutorial_overlay.focused_control if tutorial_overlay else null
var tutorial_overlay
var feedback_layer
var dialog_controller
var help_content: Control
var help_tabs: TabContainer
var level_select_content: Control
var settings_content: Control
var language_picker: OptionButton
var localization
var audio_controller
var selected_language := ""
var music_enabled := true
var sfx_enabled := true
var haptics_enabled := true
var debug_level_selection_enabled := OS.is_debug_build()
var pending_coin_tool := ""
var pending_coin_price := 0
var pending_rewarded_coin_grant := 0
var coin_delta_panel: PanelContainer:
	get: return game_screen.coin_delta_panel if game_screen else null
var coin_delta_label: Label:
	get: return game_screen.coin_delta_label if game_screen else null
var opening_king_reveal_pending := false
var result_overlay_mode := "success"
var save_game_after_frame_pending := false
var save_repository



func _ready() -> void:
	formal_controller = FormalGameControllerScript.new()
	tutorial_controller = TutorialControllerScript.new()
	composite_controller = CompositeGameControllerScript.new()
	hint_engine = HintEngineScript.new()
	save_repository = SaveRepositoryScript.new()
	save_repository.configure(str(ProjectSettings.get_setting(SAVE_PATH_OVERRIDE_SETTING, SAVE_PATH)))
	levels = LevelStoreScript.load_levels()
	if levels.is_empty():
		_show_fatal_error("没有找到可用关卡")
		return
	composite_levels = CompositeLevelStoreScript.load_entries()
	_load_save()
	_prime_composite_level_data()
	localization = LocalizationControllerScript.new()
	localization.initialize(selected_language)
	selected_language = localization.current_locale
	localization.locale_changed.connect(_on_locale_changed)
	audio_controller = AudioControllerScript.new()
	add_child(audio_controller)
	audio_controller.set_audio_preferences(music_enabled, sfx_enabled, haptics_enabled)
	_configure_font_fallbacks()
	LevelDirectorScript.record_retention_if_needed(director_progress, _today_string(), int(Time.get_unix_time_from_system()))
	_build_ui()
	_apply_layout_direction()
	current_level_index = clampi(current_level_index, 0, levels.size() - 1)
	var resume_schedule := _schedule_for_current_level()
	current_level_index = int(resume_schedule.get("levelIndex", current_level_index))
	_load_level(current_level_index, true, resume_schedule, home_composite_entry_active)
	if tutorial_started:
		_show_home()
		_show_tutorial_resume_dialog()
	elif tutorial_completed:
		_show_home()
	else:
		_start_tutorial_step(0)


func _exit_tree() -> void:
	if composite_levels is CompositeLevelStore:
		composite_levels.finish_pending_loads()


func _prime_composite_level_data() -> void:
	if not composite_levels is CompositeLevelStore:
		return
	var unlocked: Array = []
	for raw_size in LevelDirectorScript.unlocked_sizes(player_level_number):
		var size := int(raw_size)
		if size >= CompositeLevelDirectorScript.MIN_BOARD_SIZE:
			unlocked.append(size)
	if unlocked.is_empty():
		return
	var primary_size := int(unlocked.back())
	if bool(active_schedule.get("assemblyEnabled", false)):
		primary_size = int(active_schedule.get("selectedSize", primary_size))
	# Restoring an assembly run needs its complete board data immediately. During a
	# normal startup, start the preferred size first but do not hold back the home
	# screen while the binary resource is decoded.
	if bool(active_schedule.get("assemblyEnabled", false)):
		composite_levels.load_size(primary_size)
	else:
		composite_levels.request_size_async(primary_size)
	call_deferred("_request_background_composite_sizes", unlocked, primary_size)


func _request_background_composite_sizes(unlocked: Array, primary_size: int) -> void:
	if not composite_levels is CompositeLevelStore:
		return
	# Give the preferred size a head start before submitting lower-priority loads.
	await get_tree().create_timer(0.45).timeout
	var pending_sizes: Array[int] = []
	for raw_size in unlocked:
		var size := int(raw_size)
		if size != primary_size:
			pending_sizes.append(size)
	for next_size in [6, 7, 8, 9]:
		if next_size <= primary_size:
			continue
		if player_level_number >= LevelDirectorScript.minimum_display_for_size(next_size) - 2:
			if not pending_sizes.has(next_size):
				pending_sizes.append(next_size)
		break
	for size in pending_sizes:
		composite_levels.request_size_async(size)
		await get_tree().create_timer(0.45).timeout


func _configure_font_fallbacks() -> void:
	if not UI_FONT.fallbacks.has(ARABIC_FONT):
		UI_FONT.fallbacks.append(ARABIC_FONT)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	home_screen = HomePageScript.new()
	home_screen.configure(Callable(localization, "text"))
	home_screen.start_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_start_current_flow()
	)
	home_screen.composite_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_start_home_composite_flow()
	)
	home_screen.tutorial_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_replay_tutorial_preserving_progress()
	)
	add_child(home_screen)
	home_start_button = home_screen.start_button
	home_composite_button = home_screen.composite_button

	formal_level_page = FormalLevelPageScript.new()
	formal_level_page.configure(coin_count, Callable(localization, "text"), debug_level_selection_enabled)
	_connect_level_page_signals(formal_level_page)
	add_child(formal_level_page)
	formal_level_page.hide()

	composite_level_page = CompositeLevelPageScript.new()
	composite_level_page.configure(coin_count, Callable(localization, "text"), debug_level_selection_enabled)
	_connect_level_page_signals(composite_level_page)
	add_child(composite_level_page)
	composite_level_page.hide()
	_activate_level_page(home_composite_entry_active)
	_build_opening_king_overlay()
	result_page = ResultPageScript.new()
	result_page.configure(Callable(localization, "text"))
	result_page.primary_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_completion_primary_pressed()
	)
	result_page.secondary_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_completion_secondary_pressed()
	)
	result_page.music_requested.connect(audio_controller.play_result_music)
	result_page.music_stop_requested.connect(audio_controller.stop_result_music)
	result_page.sound_requested.connect(audio_controller.play_result_sound)
	add_child(result_page)
	feedback_layer = FeedbackLayerScript.new()
	feedback_layer.configure()
	add_child(feedback_layer)
	toast_label = feedback_layer.toast_label
	tutorial_overlay = TutorialOverlayScript.new()
	tutorial_overlay.configure()
	tutorial_overlay.set_board(board)
	add_child(tutorial_overlay)
	tutorial_center_popup = tutorial_overlay.center_popup
	tutorial_hand_label = tutorial_overlay.hand_label
	_build_dialog_controller()
	_build_help_dialog()
	if debug_level_selection_enabled:
		_build_level_select_dialog()
	_build_settings_dialog()
	localization.localize_tree(self, true)


func _set_result_overlay_mode(mode: String) -> void:
	result_overlay_mode = mode
	if result_page:
		result_page.overlay_mode = mode


func _connect_level_page_signals(page) -> void:
	page.home_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_show_home()
	)
	page.help_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_on_help()
	)
	page.settings_requested.connect(func() -> void:
		audio_controller.play_ui_tap()
		_on_settings()
	)
	if debug_level_selection_enabled:
		page.level_select_requested.connect(_open_level_select)
	page.tutorial_requested.connect(_on_tutorial_button_pressed)
	page.clear_requested.connect(_clear_board)
	page.crown_find_requested.connect(_use_crown_find)
	page.hint_requested.connect(_use_hint)
	page.cell_pressed.connect(_on_cell_pressed)
	page.cell_double_pressed.connect(_on_cell_double_pressed)
	page.cell_drag_started.connect(_on_cell_drag_started)
	page.cell_dragged.connect(_on_cell_dragged)
	page.cell_drag_ended.connect(_on_cell_drag_ended)
	page.assembly_placement_requested.connect(_on_assembly_placement_requested)
	page.assembly_return_requested.connect(_on_assembly_return_requested)
	page.assembly_pickup_started.connect(_on_assembly_pickup_started)
	page.assembly_snap_target_changed.connect(_on_assembly_snap_target_changed)
	page.assembly_placement_rejected.connect(_on_assembly_placement_rejected)
	page.assembly_intro_finished.connect(_on_composite_intro_finished)


func _activate_level_page(use_composite_page: bool) -> void:
	var target = composite_level_page if use_composite_page else formal_level_page
	if not target or game_screen == target:
		return
	var was_visible := game_screen != null and game_screen.visible
	if formal_level_page:
		formal_level_page.hide()
	if composite_level_page:
		composite_level_page.hide()
	game_screen = target
	target.set_coin_balance(coin_count)
	target.board.set_haptics_enabled(haptics_enabled)
	if tutorial_overlay:
		tutorial_overlay.set_board(board)
	if was_visible:
		game_screen.show()


func _build_opening_king_overlay() -> void:
	opening_king_overlay = OpeningKingOverlayScript.new()
	opening_king_overlay.configure(Callable(localization, "set_control_text"))
	add_child(opening_king_overlay)
	opening_king_panel = opening_king_overlay.panel
	opening_king_title = opening_king_overlay.title_label
	opening_king_count_label = opening_king_overlay.count_label
	opening_king_source_label = opening_king_overlay.source_row
	opening_king_source_count_label = opening_king_overlay.source_count_label


func _build_dialog_controller() -> void:
	dialog_controller = DialogControllerScript.new()
	dialog_controller.set_localizer(Callable(localization, "text"))
	dialog_controller.action_selected.connect(_on_dialog_action_selected)
	dialog_controller.cancelled.connect(_on_dialog_cancelled)
	add_child(dialog_controller)


func _build_help_dialog() -> void:
	help_content = HelpDialogContentScript.new()
	help_content.configure(Callable(localization, "text"))
	help_content.replay_composite_intro_requested.connect(_replay_composite_intro_from_help)
	help_tabs = help_content
	dialog_controller.register_content("help_rules", help_content)


func _build_level_select_dialog() -> void:
	if not debug_level_selection_enabled:
		return
	var level_select_script = load(LEVEL_SELECT_DIALOG_PATH)
	if not level_select_script:
		push_error("Debug level-select content is unavailable")
		return
	level_select_content = level_select_script.new()
	level_select_content.configure(Callable(localization, "text"))
	level_select_picker = level_select_content.picker
	dialog_controller.register_content("level_select", level_select_content)


func _build_settings_dialog() -> void:
	settings_content = SettingsDialogContentScript.new()
	settings_content.configure(Callable(localization, "text"))
	language_picker = settings_content.language_picker
	_refresh_language_picker()
	dialog_controller.register_content("settings", settings_content)


func _schedule_for_current_level() -> Dictionary:
	_sync_director_completed_levels()
	if not active_schedule.is_empty():
		var schedule_index := int(active_schedule.get("levelIndex", current_level_index))
		if schedule_index >= 0 and schedule_index < levels.size():
			if int(active_schedule.get("displayLevel", player_level_number)) == player_level_number:
				return active_schedule
	return LevelDirectorScript.schedule_for_display_level(levels, player_level_number, director_progress)



func _schedule_for_manual_level(index: int) -> Dictionary:
	var display := index + 1 if index < LevelDirectorScript.FIXED_OPENING_COUNT else player_level_number
	var mode := "fixed" if index < LevelDirectorScript.FIXED_OPENING_COUNT else "manual"
	return LevelDirectorScript.manual_schedule_for_level(levels, index, maxi(1, display), mode)


func _sync_director_completed_levels() -> void:
	LevelDirectorScript.normalize_progress(director_progress)
	director_progress["completedLevelIds"] = completed_levels.duplicate()


func _load_level(index: int, allow_resume: bool = false, schedule: Dictionary = {}, force_resume: bool = false) -> void:
	_cancel_opening_king_intro()
	result_page.stop_petals()
	in_tutorial = false
	if coach_panel:
		coach_panel.hide()
	_hide_tutorial_hand()
	if tutorial_skip_button:
		tutorial_skip_button.hide()
	if level_picker:
		level_picker.disabled = false
	if schedule.is_empty():
		schedule = _schedule_for_manual_level(index)
	active_schedule = schedule.duplicate(true)
	current_level_index = int(active_schedule.get("levelIndex", index))
	current_level_index = clampi(current_level_index, 0, levels.size() - 1)
	player_level_number = maxi(1, int(active_schedule.get("displayLevel", player_level_number)))
	current_level = levels[current_level_index].duplicate(true)
	_prepare_composite_level(allow_resume)
	_activate_level_page(composite_mode)
	is_completed = false
	is_failed = false
	hint_engine.reset_session()
	move_history.clear()
	result_page.stop_lion_animation()
	completion_overlay.hide()

	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])
	current_heart_limit = _heart_limit_for_display_level(player_level_number)
	var can_resume := allow_resume and _can_restore_saved_level(rows, cols, force_resume)
	if can_resume:
		cell_states = resume_states.duplicate(true)
		is_completed = resume_completed
		is_failed = resume_failed
		heart_count = clampi(heart_count, 0, current_heart_limit)
		if run_started_unix <= 0:
			run_started_unix = int(Time.get_unix_time_from_system())
	else:
		cell_states = _blank_states(rows, cols)
		heart_count = current_heart_limit
		run_started_unix = int(Time.get_unix_time_from_system())
		run_move_count = 0
		run_hint_count = 0
		run_direct_find_count = 0
		run_coin_exchange_count = 0
	_update_active_king_positions()
	_apply_king_positions_to_state()

	level_label.text = _display_level_title()
	if help_button:
		help_button.show()
	if completion_next_button:
		completion_next_button.text = _t("下一关")
	if completion_replay_button:
		completion_replay_button.text = _t("主菜单")
		completion_replay_button.show()
	if hint_button:
		hint_button.show()
		hint_button.disabled = is_failed
	if crown_find_button:
		crown_find_button.show()
		crown_find_button.disabled = is_failed
	if clear_button:
		clear_button.show()
		clear_button.disabled = is_failed
	_update_heart_label()
	_update_crown_find_button()
	_update_level_picker()
	coach_label.text = _level_coach_text()
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	if progress_bar:
		progress_bar.max_value = int(current_level["targetCount"])
	board.set_level(current_level, cell_states, REGION_COLORS)
	_validate_and_update(false)
	_apply_composite_phase_ui()
	if not _is_assembly_phase():
		_request_opening_king_reveal()
	_update_home()
	if is_completed:
		_prepare_success_result_page()
		completion_overlay.show()
		_save_game()
	elif is_failed:
		_prepare_failure_result_page()
		completion_overlay.show()
		_save_game()


func _prepare_composite_level(allow_resume: bool) -> void:
	composite_mode = false
	composite_phase = "crown"
	# Offline runtime data is shared by the loaded size catalog. Release this
	# session reference without mutating the catalog entry itself.
	composite_data = {}
	composite_placements.clear()
	composite_placement_history.clear()
	composite_tray_slots.clear()
	composite_deadlocked = false
	composite_final_layout.clear()
	var level_id := int(current_level.get("levelId", -1))
	var saved_matches := allow_resume and int(resume_composite_state.get("levelId", -2)) == level_id
	var saved_phase := str(resume_composite_state.get("phase", "")) if saved_matches else ""
	if saved_matches and (saved_phase == "crown" or saved_phase == "transition"):
		var final_regions = resume_composite_state.get("finalRegions", [])
		var final_solution = resume_composite_state.get("finalSolution", [])
		if _composite_final_level_is_valid(final_regions, final_solution):
			composite_mode = true
			composite_phase = "crown"
			current_level["regions"] = final_regions.duplicate(true)
			current_level["solution"] = final_solution.duplicate(true)
			composite_final_layout = {
				"signature": str(resume_composite_state.get("layoutSignature", "")),
				"regions": final_regions.duplicate(true),
				"solution": final_solution.duplicate(true)
			}
			return

	if not bool(active_schedule.get("assemblyEnabled", false)) or int(current_level.get("rows", 0)) < 6:
		return
	var difficulty_pattern := str(active_schedule.get("assemblyDifficultyPattern", ""))
	if difficulty_pattern.is_empty():
		difficulty_pattern = str(current_level.get("difficulty", "medium"))
	var seed := int(resume_composite_state.get("seed", 0)) if saved_matches else int(active_schedule.get("assemblySeed", 0))
	var prebuilt_composite = active_schedule.get("assemblyPrebuiltData", {})
	active_schedule.erase("assemblyPrebuiltData")
	if _prebuilt_composite_matches(prebuilt_composite, seed, difficulty_pattern):
		composite_data = (prebuilt_composite as Dictionary).duplicate(true)
	else:
		composite_data = CompositeLevelStoreScript.find(
			composite_levels,
			int(current_level.get("levelId", -1)),
			difficulty_pattern
		)
	if composite_data.is_empty():
		active_schedule["assemblyEnabled"] = false
		return
		active_schedule["assemblySeed"] = int(composite_data.get("seed", seed))
	active_schedule["assemblyDifficultyPattern"] = str(composite_data.get("difficulty", difficulty_pattern))
	composite_mode = true
	composite_phase = "assembly"
	active_schedule["kingPositions"] = []
	var saved_data_version := int(resume_composite_state.get("dataVersion", 0))
	var saved_data_matches := (
		saved_matches
		and saved_phase == "assembly"
		and saved_data_version == int(composite_data.get("version", -1))
		and int(resume_composite_state.get("seed", 0)) == int(composite_data.get("seed", -1))
	)
	if saved_data_matches:
		composite_placements = CompositeLevelScript.sanitize_placements(composite_data, resume_composite_state.get("placements", {}))
		composite_placement_history = _sanitize_composite_placement_history(
			resume_composite_state.get("placementHistory", []),
			composite_placements
		)
		composite_deadlocked = bool(resume_composite_state.get("deadlocked", false)) and not composite_placement_history.is_empty()
	else:
		composite_placements = CompositeLevelScript.empty_placements()
	composite_tray_slots = CompositeLevelScript.sanitize_tray_slots(
		composite_data,
		composite_placements,
		resume_composite_state.get("traySlots", [])
		if saved_data_matches
		else []
	)


func _prebuilt_composite_matches(raw_data, seed: int, difficulty_pattern: String) -> bool:
	return CompositePlacementEngineScript.prebuilt_matches(raw_data, current_level, seed, difficulty_pattern)


func _composite_final_level_is_valid(regions, solution) -> bool:
	return CompositePlacementEngineScript.final_level_is_valid(current_level, regions, solution)


func _sanitize_composite_placement_history(raw_history, placements: Dictionary) -> Array:
	return CompositePlacementEngineScript.sanitize_placement_history(raw_history, placements)


func _is_assembly_phase() -> bool:
	return composite_controller.is_assembly_phase()


func _assembly_allowed_origins() -> Dictionary:
	return composite_controller.allowed_origins()


func _assembly_direct_find_target() -> Dictionary:
	return composite_controller.direct_find_target()


func _assembly_hint_target() -> Dictionary:
	return composite_controller.hint_target()


func _assembly_origin_in_list(origin: Array, origins: Array) -> bool:
	return CompositePlacementEngineScript.origin_in_list(origin, origins)


func _clear_assembly_placements() -> void:
	if not composite_controller.clear_placements():
		return
	audio_controller.play_block_clear()
	assembly_view.update_state(composite_placements, _assembly_allowed_origins(), composite_tray_slots)
	_update_assembly_tool_buttons()
	_save_game()
	_show_toast("已清除已放置方块")


func _use_assembly_direct_find() -> void:
	var target := _assembly_direct_find_target()
	if target.is_empty():
		_show_toast("当前没有可以直接填满的颜色区域")
		_update_assembly_tool_buttons()
		return
	var evaluation: Dictionary = composite_controller.evaluate_direct_find(target)
	if not bool(evaluation.get("valid", false)):
		_show_toast("当前局面无法直接填充这个颜色区域")
		return
	var uses_free_count := crown_find_count > 0
	if not uses_free_count and not _spend_coins_for_tool(CoinEconomyScript.TOOL_CROWN_FIND):
		return
	if uses_free_count:
		crown_find_count -= 1
	composite_controller.commit_direct_find(target, evaluation)
	var completed_layout: Dictionary = evaluation.get("layout", {})
	if not completed_layout.is_empty():
		assembly_view.update_state(composite_placements, {}, composite_tray_slots)
		_update_assembly_tool_buttons()
		_complete_composite_assembly(completed_layout)
		return
	assembly_view.update_state(composite_placements, evaluation.get("allowedByPiece", {}), composite_tray_slots)
	_update_assembly_tool_buttons()
	_save_game()
	_show_toast("直找：已填满%s区域" % _region_name(int(target["regionId"])))
	audio_controller.play_block_region_complete()


func _use_assembly_hint() -> void:
	var target := _assembly_hint_target()
	if target.is_empty():
		_show_toast("当前没有可以提示的放置位置")
		_update_assembly_tool_buttons()
		return
	if hint_count > 0:
		hint_count -= 1
	elif not _spend_coins_for_tool(CoinEconomyScript.TOOL_HINT):
		return
	assembly_view.show_piece_hint(int(target["pieceId"]), target["origin"])
	_update_assembly_tool_buttons()
	run_hint_count += 1
	audio_controller.play_hint()
	_save_game()


func _update_assembly_tool_buttons() -> void:
	if not _is_assembly_phase():
		return
	var direct_target := _assembly_direct_find_target()
	var hint_target := _assembly_hint_target()
	var hint_price := _current_tool_price(CoinEconomyScript.TOOL_HINT)
	game_screen.present_tool("clear", {"label": "清除", "status": "free_forever", "disabled": composite_placements.is_empty()})
	game_screen.present_tool("crown", {
		"label": "直找",
		"status": "free" if crown_find_count > 0 else "paid",
		"value": crown_find_count if crown_find_count > 0 else _current_tool_price(CoinEconomyScript.TOOL_CROWN_FIND),
		"disabled": composite_deadlocked or direct_target.is_empty()
	})
	game_screen.present_tool("hint", {
		"label": "提示",
		"status": _hint_tool_status(),
		"value": hint_count if hint_count > 0 else hint_price,
		"disabled": composite_deadlocked or hint_target.is_empty()
	})


func _apply_composite_phase_ui() -> void:
	if not assembly_view or not board or not action_bar or not progress_row:
		return
	if _is_assembly_phase():
		progress_row.hide()
		assembly_tray_target.show()
		if assembly_stage_label:
			assembly_stage_label.text = str(composite_data.get("difficulty", "medium")).to_upper()
			assembly_stage_label.show()
		board.modulate.a = 0.0
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_screen.set_all_tools_visible(true)
		assembly_view.configure(
			composite_data,
			composite_placements,
			REGION_COLORS,
			_assembly_allowed_origins(),
			composite_tray_slots
		)
		assembly_view.input_locked = composite_deadlocked
		_update_assembly_tool_buttons()
		if composite_deadlocked:
			call_deferred("_show_composite_deadlock")
	else:
		progress_row.show()
		assembly_tray_target.hide()
		if assembly_stage_label:
			assembly_stage_label.hide()
		board.modulate.a = 1.0
		board.mouse_filter = Control.MOUSE_FILTER_STOP
		assembly_view.deactivate()
		game_screen.set_all_tools_visible(true)
		game_screen.present_tool("clear", {"label": "清除", "status": "free_forever", "disabled": _clearable_marks_empty()})
		_update_crown_find_button()
		_update_hint_button()


func _on_assembly_placement_requested(piece_id: int, origin: Array) -> void:
	if not _is_assembly_phase() or origin.size() < 2:
		return
	var completed_regions_before := _assembly_completed_region_count()
	var evaluation: Dictionary = composite_controller.place(piece_id, origin)
	if not bool(evaluation.get("valid", false)):
		audio_controller.play_block_reject()
		return
	var layout: Dictionary = evaluation.get("layout", {})
	if not layout.is_empty():
		assembly_view.update_state(composite_placements, {}, composite_tray_slots)
		_complete_composite_assembly(layout)
	elif composite_deadlocked:
		audio_controller.play_block_place(_assembly_piece_size(piece_id))
		assembly_view.update_state(composite_placements, {}, composite_tray_slots)
		assembly_view.play_placement_feedback(piece_id, origin)
		_save_game()
		_show_composite_deadlock()
	else:
		var completed_regions_after := _assembly_completed_region_count()
		if completed_regions_after > completed_regions_before:
			audio_controller.play_block_region_complete(_assembly_piece_size(piece_id))
		else:
			audio_controller.play_block_place(_assembly_piece_size(piece_id))
		assembly_view.update_state(
			composite_placements,
			evaluation.get("allowedByPiece", {}),
			composite_tray_slots
		)
		assembly_view.play_placement_feedback(piece_id, origin)
		_save_game()


func _on_assembly_return_requested(piece_id: int, preferred_slot_index: int = -1) -> void:
	if not _is_assembly_phase():
		return
	var returned_slot: int = composite_controller.return_piece(piece_id, preferred_slot_index)
	assembly_view.update_state(composite_placements, _assembly_allowed_origins(), composite_tray_slots)
	if returned_slot >= 0:
		audio_controller.play_block_return()
		assembly_view.focus_tray_slot(returned_slot, false)
		assembly_view.play_return_feedback(returned_slot)
	# Do not block the release event on JSON serialization and file I/O. The
	# updated tray is already visible; persist the same state after this frame.
	_queue_save_game_after_frame()


func _on_assembly_pickup_started(piece_size: int) -> void:
	if _is_assembly_phase():
		audio_controller.play_block_pickup(piece_size)


func _on_assembly_snap_target_changed() -> void:
	if _is_assembly_phase():
		audio_controller.play_block_snap()


func _on_assembly_placement_rejected() -> void:
	if _is_assembly_phase():
		audio_controller.play_block_reject()


func _assembly_piece_size(piece_id: int) -> int:
	for piece in composite_data.get("pieces", []):
		if int(piece.get("pieceId", -1)) == piece_id:
			return maxi(1, (piece.get("cells", []) as Array).size())
	return 1


func _assembly_completed_region_count() -> int:
	var region_piece_counts := {}
	var placed_region_piece_counts := {}
	for piece in composite_data.get("pieces", []):
		var region_id := int(piece.get("regionId", -1))
		region_piece_counts[region_id] = int(region_piece_counts.get(region_id, 0)) + 1
		if composite_placements.has(str(int(piece.get("pieceId", -1)))):
			placed_region_piece_counts[region_id] = int(placed_region_piece_counts.get(region_id, 0)) + 1
	var completed := 0
	for region_id in region_piece_counts:
		if int(placed_region_piece_counts.get(region_id, 0)) == int(region_piece_counts[region_id]):
			completed += 1
	return completed


func _complete_composite_assembly(layout: Dictionary) -> void:
	if not _is_assembly_phase() or layout.is_empty():
		return
	composite_final_layout = layout.duplicate(true)
	composite_phase = "transition"
	audio_controller.play_assembly_complete()
	_save_game()
	await assembly_view.play_flatten_transition()
	if composite_final_layout.is_empty():
		return
	current_level["regions"] = composite_final_layout["regions"].duplicate(true)
	current_level["solution"] = composite_final_layout["solution"].duplicate(true)
	active_schedule["assemblyLayoutSignature"] = str(composite_final_layout.get("signature", ""))
	active_king_positions.clear()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	board.set_level(current_level, cell_states, REGION_COLORS)
	composite_phase = "crown"
	_apply_composite_phase_ui()
	_validate_and_update(false)
	_save_game()


func _composite_save_state() -> Dictionary:
	return composite_controller.save_state(current_level, active_schedule)


func _maybe_play_composite_intro() -> void:
	if not _is_assembly_phase() or composite_tutorial_seen or composite_intro_running or not game_screen.visible:
		return
	composite_intro_running = true
	composite_intro_marks_seen = true
	assembly_view.play_intro()


func _on_composite_intro_finished() -> void:
	composite_intro_running = false
	if composite_intro_marks_seen:
		composite_tutorial_seen = true
		composite_intro_marks_seen = false
		_save_game()


func _can_restore_saved_level(rows: int, cols: int, force_resume: bool = false) -> bool:
	if resume_level_id != int(current_level["levelId"]):
		return false
	if not _states_match_size(resume_states, rows, cols):
		return false
	var display := int(active_schedule.get("displayLevel", player_level_number))
	if not force_resume and not resume_completed and display <= LevelDirectorScript.FIXED_OPENING_COUNT:
		return false
	return true


func _request_opening_king_reveal() -> void:
	if active_king_positions.is_empty() or is_completed or is_failed:
		opening_king_reveal_pending = false
		if board:
			board.reveal_all_prepared_kings()
		return
	opening_king_reveal_pending = true
	_play_pending_opening_king_reveal()


func _play_pending_opening_king_reveal() -> void:
	if not opening_king_reveal_pending:
		return
	if not game_screen or not game_screen.visible:
		return
	if not board or active_king_positions.is_empty():
		return
	opening_king_reveal_pending = false
	board.prepare_king_reveal(active_king_positions)
	_play_opening_king_intro(active_king_positions.duplicate())


func _play_opening_king_intro(cells: Array) -> void:
	if not game_screen or not game_screen.visible:
		opening_king_reveal_pending = false
		if board:
			board.reveal_all_prepared_kings()
		return
	if not opening_king_overlay or cells.is_empty():
		board.reveal_all_prepared_kings()
		board.play_king_reveal(cells)
		return
	var total_count := int(current_level.get("targetCount", cells.size()))
	var base_progress := maxi(0, _piece_positions().size() - cells.size())
	var completed: bool = await opening_king_overlay.play(
		cells,
		total_count,
		base_progress,
		board,
		progress_bar,
		progress_label
	)
	if completed:
		_validate_and_update(false)


func _cancel_opening_king_intro(keep_pending: bool = false) -> void:
	if opening_king_overlay:
		opening_king_overlay.cancel()
	if board:
		board.reveal_all_prepared_kings()
	opening_king_reveal_pending = keep_pending and not active_king_positions.is_empty() and not is_completed and not is_failed


func _level_coach_text() -> String:
	var king_info := str(current_level.get("kingInfo", "")).strip_edges()
	var prefix := _t("难度挑战： ") if bool(active_schedule.get("isMilestoneChallenge", false)) else ""
	if king_info != "":
		return prefix + _runtime_text(
			king_info,
			"请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。"
		)
	var display := int(active_schedule.get("displayLevel", player_level_number))
	if str(active_schedule.get("mode", "")) == "fixed" and display <= 9 and not active_king_positions.is_empty():
		return prefix + _t("国王提示：开局已展示一个皇冠，请围绕它继续推理。")
	return prefix + _runtime_text(
		str(current_level.get("tutorial", "放置全部皇冠，满足行、列、颜色区域和相邻规则。")),
		"请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。"
	)


func _display_level_title() -> String:
	if home_composite_entry_active:
		return _t("拼块挑战 · 第 %d 局", [maxi(1, home_composite_round)])
	if bool(active_schedule.get("isMilestoneChallenge", false)):
		return _t("关卡 %d · 难度挑战", [player_level_number])
	return _t("关卡 %d", [player_level_number])


func _update_active_king_positions() -> void:
	active_king_positions.clear()
	if in_tutorial:
		return
	var raw_positions = active_schedule.get("kingPositions", [])
	if not active_schedule.has("kingPositions") or not (raw_positions is Array):
		if current_level.has("kingPosition"):
			raw_positions = [current_level.get("kingPosition", [])]
	for raw in raw_positions:
		var king := _parse_king_position(raw)
		if king.x >= 0 and not active_king_positions.has(king):
			active_king_positions.append(king)


func _parse_king_position(raw) -> Vector2i:
	if not (raw is Array) or raw.size() < 2:
		return Vector2i(-1, -1)
	var row := int(raw[0])
	var col := int(raw[1])
	if row < 0 or row >= int(current_level.get("rows", 0)) or col < 0 or col >= int(current_level.get("cols", 0)):
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _apply_king_positions_to_state() -> void:
	for king in active_king_positions:
		if king.x >= 0:
			cell_states[king.y][king.x] = "king"


func _is_king_cell(row: int, col: int) -> bool:
	for king in active_king_positions:
		if king.x == col and king.y == row:
			return true
	return false


func _is_piece_state(state: String) -> bool:
	return CrownRuleEngineScript.is_piece_state(state)


func _on_cell_pressed(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_cell_pressed(row, col)
		return
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	var result: Dictionary = formal_controller.press(row, col)
	if result.is_empty():
		return
	hint_engine.reset_session()
	board.set_guides({})
	cell_states = result["states"]
	if str(result["state"]) == "blocked":
		audio_controller.play_mark()
	else:
		audio_controller.play_erase()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	run_move_count += 1
	_validate_and_update(true)
	_save_game()


func _on_cell_double_pressed(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_cell_double_pressed(row, col)
		return
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	var result: Dictionary = formal_controller.double_press(row, col)
	if result.is_empty():
		return
	hint_engine.reset_session()
	board.set_guides({})
	cell_states = result["states"]
	board.set_states(cell_states)
	if bool(result["correct"]):
		board.play_cell_feedback(row, col)
		var found_count := _piece_positions().size()
		var total_count := int(current_level.get("targetCount", 1))
		audio_controller.play_crown_place(found_count, total_count, found_count >= total_count)
		_validate_and_update(true)
		coach_label.text = _t("已放置皇冠。继续用行、列、颜色区域和相邻规则检查其它位置。")
		coach_label.add_theme_color_override("font_color", Color("#72552B"))
	else:
		board.play_wrong_feedback(row, col)
		audio_controller.play_wrong_crown(heart_count > 0)
		var crown_find_count_before_wrong := crown_find_count
		_validate_and_update(false)
		coach_label.text = _t("这个位置不是皇冠，已标记为 X。")
		coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
		_consume_heart_for_wrong_crown()
		crown_find_count = crown_find_count_before_wrong
		_update_crown_find_button()
	_save_game()


func _on_cell_drag_started(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_drag_started(row, col)
		return
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	var result: Dictionary = formal_controller.begin_drag(row, col)
	if result.is_empty():
		return
	hint_engine.reset_session()
	board.set_guides({})
	_apply_formal_drag_result(result)


func _on_cell_dragged(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_dragged(row, col)
		return
	_apply_drag_cell(row, col)


func _on_cell_drag_ended() -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_drag_ended()
		return
	if formal_controller.drag_mode == "":
		return
	if formal_controller.end_drag():
		_validate_and_update(true)
		_save_game()


func _apply_drag_cell(row: int, col: int) -> void:
	var result: Dictionary = formal_controller.drag_to(row, col)
	if not result.is_empty():
		_apply_formal_drag_result(result)


func _apply_formal_drag_result(result: Dictionary) -> void:
	cell_states = result["states"]
	var cell: Vector2i = result["cell"]
	if str(result["state"]) == "blocked":
		audio_controller.play_mark()
	else:
		audio_controller.play_erase(true)
	board.set_states(cell_states)
	board.play_cell_feedback(cell.y, cell.x)

func _undo() -> void:
	if in_tutorial:
		_use_tutorial_undo()
		return
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	var result: Dictionary = formal_controller.undo()
	if result.is_empty():
		return
	cell_states = result["states"]
	board.set_states(cell_states)
	_validate_and_update(false)
	run_move_count += 1
	audio_controller.play_erase()
	_save_game()


func _clear_board() -> void:
	if _is_assembly_phase():
		_clear_assembly_placements()
		return
	if in_tutorial:
		_use_tutorial_clear()
		return
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	var result: Dictionary = formal_controller.clear_board()
	if result.is_empty():
		return
	cell_states = result["states"]
	hint_engine.reset_session()
	board.set_states(cell_states)
	board.set_guides({})
	_validate_and_update(false)
	run_move_count += 1
	audio_controller.play_clear()
	_save_game()
	_show_toast("已清除普通标记和错误标记，提示皇冠已保留")


func _current_tool_price(tool: String) -> int:
	if current_level.is_empty():
		return 1
	return player_wallet.tool_price(tool, _economy_display_level())


func _economy_display_level() -> int:
	if home_composite_entry_active and not home_composite_progress_snapshot.is_empty():
		return maxi(1, int(home_composite_progress_snapshot.get("playerLevelNumber", player_level_number)))
	return maxi(1, player_level_number)


func _spend_coins_for_tool(tool: String) -> bool:
	var transaction: Dictionary = player_wallet.spend_tool(tool, _economy_display_level())
	if not bool(transaction.get("success", false)):
		_show_coin_shortage_dialog(tool, int(transaction.get("price", 0)))
		return false
	_update_coin_label()
	_update_hint_button()
	_update_crown_find_button()
	return true


func _show_coin_shortage_dialog(tool: String, price: int) -> void:
	pending_coin_tool = tool
	pending_coin_price = price
	pending_rewarded_coin_grant = CoinEconomyScript.rewarded_ad_coin_grant(
		price,
		coin_count,
		_economy_display_level()
	)
	var tool_name := "逻辑提示"
	if tool == CoinEconomyScript.TOOL_CROWN_FIND:
		tool_name = "皇冠位置提醒"
	elif tool == CoinEconomyScript.TOOL_REVIVE:
		tool_name = "保留棋盘复活"
	var shortage := maxi(0, price - coin_count)
	tool_name = _t(tool_name)
	var message := _t("%s需要 %d 金币。\n当前持有 %d，还差 %d。\n\n可购买金币，或主动观看一次激励广告补足本次需求。", [tool_name, price, coin_count, shortage])
	dialog_controller.show_dialog(
		"coin_shortage",
		"金币不足",
		message,
		"",
		[
			{"id": "later", "text": "稍后再说", "variant": "secondary"},
			{"id": "purchase", "text": "购买金币", "variant": "weak"},
			{"id": "rewarded", "text": _t("观看广告 +%d", [pending_rewarded_coin_grant]), "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		false
	)


func _use_hint() -> void:
	if _is_assembly_phase():
		_use_assembly_hint()
		return
	if in_tutorial:
		_use_tutorial_hint()
		return
	if is_completed or is_failed:
		return

	var hint := _build_best_next_hint()
	if hint.is_empty():
		_show_toast("当前没有明显可提示的位置")
		return
	if hint_count > 0:
		hint_count -= 1
	elif not _spend_coins_for_tool(CoinEconomyScript.TOOL_HINT):
		return

	var guides: Dictionary = hint.get("guides", {})
	board.set_guides(guides)
	var target: Vector2i = hint["target"]
	if target.x >= 0:
		board.play_guide_feedback(target.y, target.x)
	else:
		board.play_guide_feedback_for_cells(guides.keys())
	_update_coin_label()
	_update_hint_button()
	run_hint_count += 1
	audio_controller.play_hint()
	_save_game()


func _use_crown_find() -> void:
	if _is_assembly_phase():
		_use_assembly_direct_find()
		return
	if in_tutorial:
		_use_tutorial_crown_find()
		return
	if is_completed or is_failed:
		return
	var target := _next_findable_solution_cell()
	if target.x < 0:
		_show_toast("当前已经没有可直接找到的皇冠")
		_update_crown_find_button()
		return
	var uses_free_count := crown_find_count > 0
	if not uses_free_count and not _spend_coins_for_tool(CoinEconomyScript.TOOL_CROWN_FIND):
		return

	_push_history()
	hint_engine.reset_session()
	board.set_guides({})
	if uses_free_count:
		crown_find_count -= 1
	run_direct_find_count += 1
	cell_states[target.y][target.x] = "hint"
	audio_controller.play_crown_reveal()
	board.set_states(cell_states)
	board.play_cell_feedback(target.y, target.x)
	_validate_and_update(true)
	run_move_count += 1
	_update_crown_find_button()
	_save_game()
	_show_toast("已直接找到一个皇冠")


func _next_findable_solution_cell() -> Vector2i:
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	return formal_controller.next_findable_solution_cell()


func _validate_and_update(allow_completion: bool) -> void:
	formal_controller.bind(current_level, cell_states, active_king_positions, is_completed, is_failed)
	var validation: Dictionary = formal_controller.validation()
	var pieces: Array = validation["pieces"]
	var conflicts: Dictionary = validation["conflicts"]
	board.set_errors(conflicts if immediate_errors else {})

	if game_screen:
		game_screen.set_progress(pieces.size(), int(current_level["targetCount"]))
	if undo_button:
		undo_button.disabled = move_history.is_empty()
	if game_screen:
		game_screen.present_tool("clear", {"label": "清除", "status": "free_forever", "disabled": _clearable_marks_empty()})
	_update_crown_find_button()
	_update_hint_button()

	if not conflicts.is_empty() and immediate_errors:
		coach_label.text = "有冲突：红色格子违反了行、列、区域或相邻规则。"
		coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
		if allow_completion:
			if haptics_enabled:
				Input.vibrate_handheld(35)
	else:
		coach_label.text = _level_coach_text()
		coach_label.add_theme_color_override("font_color", Color("#72552B"))

	if not is_failed and allow_completion and bool(validation["completed"]):
		_complete_level()


func _find_conflicts(pieces: Array) -> Dictionary:
	return CrownRuleEngineScript.find_conflicts(current_level, pieces)


func _piece_conflicts_at(cell: Vector2i) -> bool:
	return _find_conflicts(_piece_positions()).has(cell)


func _build_best_next_hint() -> Dictionary:
	hint_engine.prepare(current_level, cell_states)
	return hint_engine.build_formal_x_hint()


func _region_name(region_id: int) -> String:
	var index := region_id - 1
	if index >= 0 and index < REGION_COLOR_NAMES.size():
		return "%s区域" % REGION_COLOR_NAMES[index]
	return "这个颜色区域"


func _piece_positions() -> Array:
	return CrownRuleEngineScript.piece_positions(cell_states)


func _clearable_marks_empty() -> bool:
	return FormalGameControllerScript.clearable_marks_empty(cell_states)





func _start_tutorial_step(index: int) -> void:
	if dialog_controller and dialog_controller.visible:
		dialog_controller.hide_dialog(true)
	_activate_level_page(false)
	var clamped_index := clampi(index, 0, TUTORIAL_LEVELS.size() - 1)
	current_level = TUTORIAL_LEVELS[clamped_index]
	tutorial_controller.begin_step(
		clamped_index,
		TUTORIAL_LEVELS.size(),
		_tutorial_solution_cells()[0]
	)
	if coach_panel:
		coach_panel.show()
	is_completed = false
	hint_engine.reset_session()
	completion_overlay.hide()
	_hide_tutorial_hand()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	for coordinate in current_level.get("prefill", []):
		cell_states[int(coordinate[0])][int(coordinate[1])] = "piece"
	level_label.text = _runtime_text(str(current_level.get("title", "新手教程")))
	coach_label.text = _runtime_text(
		str(current_level["tutorial"]),
		"请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。"
	)
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	if progress_bar:
		progress_bar.max_value = int(current_level["targetCount"])
		progress_bar.value = 0
	if progress_label:
		progress_label.text = "%d / %d" % [0, int(current_level["targetCount"])]
	if level_picker:
		level_picker.disabled = true
	if tutorial_skip_button:
		_update_tutorial_button()
	if completion_next_button:
		var final_action := "%s  →" % (_t("返回关卡") if _formal_progress_snapshot_is_valid(formal_progress_snapshot) else _t("进入第 1 关，开始真正的挑战"))
		completion_next_button.text = _t("下一步  →") if tutorial_step_index < TUTORIAL_LEVELS.size() - 1 else final_action
	if completion_replay_button:
		completion_replay_button.text = _t("重来本步")
		completion_replay_button.show()
	board.set_level(current_level, cell_states, REGION_COLORS)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_show_game()
	call_deferred("_focus_tutorial_cell", _tutorial_solution_cells()[0], 0.36)
	_update_hint_button()
	_update_home()
	_save_game()


func _set_tutorial_guides() -> void:
	tutorial_controller.bind(current_level, cell_states)
	board.set_guides(tutorial_controller.guides())


func _update_tutorial_action_bar() -> void:
	if not game_screen:
		return
	game_screen.reset_tool_styles()
	game_screen.present_tool("clear", {"label": "清除", "status": "tutorial", "disabled": true, "visible": true})
	if in_tutorial:
		game_screen.present_tool("hint", {
			"label": "提示",
			"status": "tutorial",
			"disabled": tutorial_interaction_stage != TUTORIAL_PHASE_HINT,
			"visible": true,
			"highlight": Color("#FFE06F") if tutorial_interaction_stage == TUTORIAL_PHASE_HINT else Color("#EAFBF0"),
			"font_color": INK if tutorial_interaction_stage == TUTORIAL_PHASE_HINT else Color("#2D9E63")
		})
		game_screen.present_tool("crown", {
			"label": "皇冠直找",
			"status": "tutorial",
			"disabled": tutorial_interaction_stage != TUTORIAL_PHASE_CROWN_FIND,
			"visible": true,
			"highlight": Color("#FFE06F") if tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND else Color("#FFF4CE"),
			"font_color": INK if tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND else Color("#B97A09")
		})
		if tutorial_interaction_stage == TUTORIAL_PHASE_HINT:
			coach_label.text = _t("点一下提示，看看下一步该观察哪里。")
		elif tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
			coach_label.text = _t("点击皇冠直找，直接找到一个皇冠。教程中不会消耗使用次数。")
		return


func _on_tutorial_cell_pressed(row: int, col: int) -> void:
	if is_completed:
		return
	_on_tutorial_single_map_pressed(row, col)


func _on_tutorial_cell_double_pressed(row: int, col: int) -> void:
	if is_completed:
		return
	_on_tutorial_single_map_double_pressed(row, col)


func _on_tutorial_drag_started(row: int, col: int) -> void:
	if is_completed:
		return
	_on_tutorial_single_map_exclusion(row, col, true)


func _on_tutorial_dragged(row: int, col: int) -> void:
	if is_completed:
		return
	_on_tutorial_single_map_exclusion(row, col, true)


func _on_tutorial_drag_ended() -> void:
	pass


func _on_tutorial_single_map_pressed(row: int, col: int) -> void:
	if tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT or tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		_on_tutorial_single_map_exclusion(row, col, false)
		return
	if tutorial_interaction_stage == TUTORIAL_PHASE_HINT:
		_show_toast("先点一下提示，看看下一步该观察哪里。")
		_focus_tutorial_control(hint_button, 0.12)
		return
	if tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
		_show_toast("先点击底部皇冠直找按钮")
		_focus_tutorial_control(crown_find_button, 0.12)
		return
	var target := _current_tutorial_place_target()
	if Vector2i(col, row) == target:
		_show_toast("请双击找到皇冠")
	else:
		_show_toast("请先操作高亮格")
	_focus_tutorial_cell(target, 0.12)


func _on_tutorial_single_map_double_pressed(row: int, col: int) -> void:
	tutorial_controller.bind(current_level, cell_states)
	var result: Dictionary = tutorial_controller.double_press(Vector2i(col, row))
	if not bool(result.get("valid", false)):
		var reason := str(result.get("reason", ""))
		if reason == "use_crown_find":
			_show_toast("这一阶段请点击底部皇冠直找按钮")
			_focus_tutorial_control(crown_find_button, 0.12)
		elif reason == "exclude":
			_show_toast("这一步请把高亮格标记为 X")
			_focus_tutorial_cell(result.get("focus", Vector2i(-1, -1)), 0.12)
		else:
			_show_toast("请双击找到皇冠")
			_focus_tutorial_cell(result.get("focus", Vector2i(-1, -1)), 0.12)
		return
	cell_states = result["states"]
	audio_controller.play_correct()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_update_tutorial_progress()
	if bool(result.get("first", false)):
		_show_toast("成功找到第一个皇冠")
	else:
		_show_toast("成功找到皇冠")
	if bool(result.get("completed", false)):
		board.set_guides({})
		_hide_tutorial_hand()
		_show_tutorial_challenge_ready()
		_save_game()
		return
	if _next_tutorial_single_map_exclusion_cell().x < 0:
		_advance_tutorial_single_map_after_exclusions()
		_save_game()
		return
	coach_label.text = _t("皇冠不能和皇冠挨着。滑过它周围的格子，把这些位置标记为 X。")
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.15)
	_save_game()


func _on_tutorial_single_map_exclusion(row: int, col: int, from_drag: bool) -> void:
	tutorial_controller.bind(current_level, cell_states)
	var result: Dictionary = tutorial_controller.press(Vector2i(col, row), from_drag)
	if str(result.get("reason", "")) == "settle":
		_advance_tutorial_single_map_after_exclusions()
		return
	if not bool(result.get("valid", false)):
		if not bool(result.get("silent", false)) and str(result.get("reason", "")) != "phase":
			_show_toast("请点击当前高亮的格子")
			_focus_tutorial_cell(result.get("focus", Vector2i(-1, -1)), 0.12)
		return
	cell_states = result["states"]
	audio_controller.play_mark()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_update_tutorial_progress()
	_advance_tutorial_single_map_after_exclusions()
	_save_game()


func _advance_tutorial_single_map_after_exclusions() -> void:
	tutorial_controller.bind(current_level, cell_states)
	var transition: Dictionary = tutorial_controller.settle_after_exclusions()
	var action := str(transition.get("action", ""))
	if action == "exclude":
		var target: Vector2i = transition.get("target", Vector2i(-1, -1))
		if int(transition.get("phase", TUTORIAL_PHASE_ADJACENT)) == TUTORIAL_PHASE_ROW_COL:
			coach_label.text = _t("每行、每列都只能有一个皇冠。这个皇冠所在的行和列，其他格都可以标记 X。")
		_set_tutorial_guides()
		_focus_tutorial_cell(target, 0.16)
		_update_tutorial_action_bar()
		return
	if action == "hint":
		coach_label.text = _t("点一下提示，看看下一步该观察哪里。")
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_tutorial_control(hint_button, 0.18)
		return
	if action == "crown_find":
		coach_label.text = _t("点击皇冠直找，直接找到一个皇冠。教程中不会消耗使用次数。")
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_tutorial_control(crown_find_button, 0.18)
		return
	if action == "direct_clue":
		var message := "每行、每列都要找到一个皇冠。现在只剩这个位置符合规则，双击找到最后一个皇冠。" if str(transition.get("reason", "")) == "final" else "每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。"
		_show_direct_tutorial_crown_clue(message, transition.get("target", Vector2i(-1, -1)))


func _tutorial_solution_cells() -> Array[Vector2i]:
	tutorial_controller.bind(current_level, cell_states)
	return tutorial_controller.solution_cells()


func _current_tutorial_place_target() -> Vector2i:
	tutorial_controller.bind(current_level, cell_states)
	return tutorial_controller.current_place_target()


func _next_tutorial_single_map_exclusion_cell() -> Vector2i:
	tutorial_controller.bind(current_level, cell_states)
	return tutorial_controller.next_single_map_exclusion_cell()


func _tutorial_single_map_valid_exclusion_cells() -> Array[Vector2i]:
	tutorial_controller.bind(current_level, cell_states)
	return tutorial_controller.valid_exclusion_cells()


func _show_direct_tutorial_crown_clue(message: String, target: Vector2i = Vector2i(-1, -1)) -> void:
	if target.x < 0:
		target = _current_tutorial_place_target()
	coach_label.text = _runtime_text(message)
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_focus_tutorial_cell(target, 0.18)


func _update_tutorial_progress() -> void:
	if progress_bar:
		progress_bar.value = _piece_positions().size()
	if progress_label:
		progress_label.text = "%d / %d" % [_piece_positions().size(), int(current_level["targetCount"])]

func _tutorial_row_col_cells(crown: Vector2i) -> Array[Vector2i]:
	tutorial_controller.bind(current_level, cell_states)
	return tutorial_controller.row_col_cells(crown)


func _show_tutorial_hand_for_cell(cell: Vector2i) -> void:
	if not in_tutorial or cell.x < 0 or cell.y < 0 or not board or not tutorial_overlay:
		return
	board.set_tutorial_focus(cell, true)
	tutorial_overlay.show_for_cell(
		cell,
		_tutorial_hand_cell_action(),
		_tutorial_slide_end_cell(cell),
		Callable(self, "_play_tutorial_hand_guide").bind(cell)
	)


func _show_tutorial_hand_for_control(control: Control) -> void:
	if not in_tutorial or not control or not tutorial_overlay:
		return
	if board:
		board.set_tutorial_focus(Vector2i(-1, -1), false)
	tutorial_overlay.show_for_control(control)


func _focus_tutorial_cell(cell: Vector2i, delay: float = 0.36) -> void:
	if not in_tutorial or cell.x < 0 or cell.y < 0 or not board:
		return
	_hide_tutorial_hand()
	var token: int = tutorial_controller.next_focus_token()
	board.set_tutorial_focus(cell, true)
	if tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		board.play_guide_feedback_for_cells(_tutorial_row_col_cells(tutorial_active_crown))
	else:
		board.play_guide_feedback(cell.y, cell.x)
	await get_tree().create_timer(delay).timeout
	if token == tutorial_controller.focus_token and in_tutorial and not is_completed:
		_show_tutorial_hand_for_cell(cell)


func _focus_tutorial_control(control: Control, delay: float = 0.24) -> void:
	if not in_tutorial or not control:
		return
	_hide_tutorial_hand()
	var token: int = tutorial_controller.next_focus_token()
	await get_tree().create_timer(delay).timeout
	if token == tutorial_controller.focus_token and in_tutorial and not is_completed and control.visible:
		_show_tutorial_hand_for_control(control)


func _play_tutorial_hand_guide(cell: Vector2i) -> void:
	if not board:
		return
	if tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		board.play_guide_feedback_for_cells(_tutorial_row_col_cells(tutorial_active_crown))
	else:
		board.play_guide_feedback(cell.y, cell.x)


func _tutorial_hand_cell_action() -> String:
	return tutorial_controller.hand_action("single_map")


func _tutorial_slide_end_cell(start_cell: Vector2i) -> Vector2i:
	for cell in _tutorial_single_map_valid_exclusion_cells():
		if cell != start_cell and cell_states[cell.y][cell.x] == "empty":
			return cell
	var rows := int(current_level.get("rows", 0))
	var cols := int(current_level.get("cols", 0))
	var fallback := Vector2i(clampi(start_cell.x + 1, 0, cols - 1), clampi(start_cell.y + 1, 0, rows - 1))
	return fallback


func _hide_tutorial_hand() -> void:
	if tutorial_controller:
		tutorial_controller.invalidate_focus()
	if tutorial_overlay:
		tutorial_overlay.hide_pointer()
	if board:
		board.set_tutorial_focus(Vector2i(-1, -1), false)


func _use_tutorial_undo() -> void:
	tutorial_controller.bind(current_level, cell_states)
	var result: Dictionary = tutorial_controller.undo()
	if result.is_empty():
		_show_toast("暂无可撤销的操作")
		return
	cell_states = result["states"]
	board.set_states(cell_states)
	audio_controller.play_erase()
	_update_tutorial_progress()
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_focus_current_single_map_tutorial_target(0.12)
	_save_game()


func _use_tutorial_clear() -> void:
	_show_toast("新手教程里请跟随高亮完成操作")


func _use_tutorial_crown_find() -> void:
	tutorial_controller.bind(current_level, cell_states)
	var result: Dictionary = tutorial_controller.use_crown_find()
	if not bool(result.get("valid", false)):
		if str(result.get("reason", "")) == "empty":
			_show_toast("当前已经没有可直接找到的皇冠")
			return
		_show_toast("皇冠直找会在稍后的教程步骤中解锁")
		_focus_current_single_map_tutorial_target(0.12)
		return
	var target: Vector2i = result["cell"]
	cell_states = result["states"]
	audio_controller.play_correct()
	board.set_states(cell_states)
	board.play_cell_feedback(target.y, target.x)
	_update_tutorial_progress()
	_show_toast("皇冠直找：已直接找到并锁定一个皇冠")
	if bool(result.get("completed", false)):
		board.set_guides({})
		_hide_tutorial_hand()
		_show_tutorial_challenge_ready()
		_save_game()
		return
	if _next_tutorial_single_map_exclusion_cell().x >= 0:
		coach_label.text = _runtime_text("皇冠直找会直接找到并锁定皇冠。继续把皇冠周围的格子标记为 X。")
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.18)
	else:
		_advance_tutorial_single_map_after_exclusions()
		if tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
			coach_label.text = _runtime_text("皇冠直找已直接找到并锁定皇冠，周围位置已经排除。继续排除同行同列。")
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	_save_game()


func _use_tutorial_hint() -> void:
	tutorial_controller.bind(current_level, cell_states)
	var result: Dictionary = tutorial_controller.use_hint()
	if not bool(result.get("valid", false)):
		_show_toast("现在先完成高亮格操作，之后再使用提示。")
		_focus_current_single_map_tutorial_target(0.12)
		return
	audio_controller.play_hint()
	_show_direct_tutorial_crown_clue(
		"每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。",
		result.get("target", Vector2i(-1, -1))
	)
	_save_game()


func _focus_current_single_map_tutorial_target(delay: float = 0.18) -> void:
	if tutorial_interaction_stage == TUTORIAL_PHASE_PLACE or tutorial_interaction_stage == TUTORIAL_PHASE_HINT_PLACE:
		_focus_tutorial_cell(_current_tutorial_place_target(), delay)
	elif tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT or tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), delay)
	elif tutorial_interaction_stage == TUTORIAL_PHASE_HINT:
		_focus_tutorial_control(hint_button, delay)
	elif tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
		_focus_tutorial_control(crown_find_button, delay)


func _show_tutorial_challenge_ready() -> void:
	is_completed = true
	_set_result_overlay_mode("tutorial")
	coach_label.text = _t("已经了解全部规则，开始真正的挑战吧！")
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	board.play_victory()
	if undo_button:
		undo_button.hide()
	if clear_button:
		clear_button.hide()
	if hint_button:
		hint_button.hide()
	if crown_find_button:
		crown_find_button.hide()
	var has_saved_progress := _formal_progress_snapshot_is_valid(formal_progress_snapshot)
	result_page.present_tutorial_complete(has_saved_progress)
	completion_next_button.text = _t("返回关卡") if has_saved_progress else _t("开始挑战")
	if completion_replay_button:
		completion_replay_button.hide()
	result_page.show_animated()
	result_page.call_deferred("play_lion_animation")


func _next_tutorial_step() -> void:
	if tutorial_step_index >= TUTORIAL_LEVELS.size() - 1:
		_finish_tutorial(false)
	else:
		_start_tutorial_step(tutorial_step_index + 1)


func _request_skip_tutorial() -> void:
	if in_tutorial:
		var skip_message := (
			"跳过后会返回进入教程前的关卡现场，之后不再自动显示新手教程。"
			if _formal_progress_snapshot_is_valid(formal_progress_snapshot)
			else "跳过后会直接进入第 1 关，之后不再自动显示新手教程。"
		)
		dialog_controller.show_dialog(
			"tutorial_skip",
			"跳过新手教程？",
			skip_message,
			"",
			[
				{"id": "continue", "text": "继续教程", "variant": "secondary"},
				{"id": "skip", "text": "确认跳过", "variant": "primary"}
			],
			UITokensScript.DIALOG_STANDARD_WIDTH,
			false
		)


func _on_tutorial_button_pressed() -> void:
	if in_tutorial:
		_request_skip_tutorial()
	else:
		_start_tutorial_step(0)


func _finish_tutorial(skipped: bool) -> void:
	tutorial_controller.finish()
	_hide_tutorial_hand()
	var restored_formal_progress := _restore_formal_progress_snapshot()
	if not restored_formal_progress:
		player_level_number = 1
		active_schedule = LevelDirectorScript.schedule_for_display_level(levels, player_level_number, director_progress)
		_load_level(int(active_schedule.get("levelIndex", 0)), false, active_schedule)
	_show_game()
	_save_game()
	if restored_formal_progress:
		_show_toast("已跳过教程，返回之前的关卡" if skipped else "新手教程完成，返回之前的关卡")
	else:
		_show_toast("已跳过教程，进入第 1 关" if skipped else "新手教程完成，进入第 1 关")


func _complete_level() -> void:
	if is_completed or is_failed:
		return
	is_completed = true
	if home_composite_entry_active:
		var result: Dictionary = RunResultServiceScript.composite_completion(active_schedule, home_composite_round)
		var composite_reward := int(result["reward"])
		player_wallet.grant(composite_reward, "composite_completion")
		CompositeCoinPolicyScript.record_round_completed(composite_coin_progress, composite_reward)
		_sync_home_composite_shared_coin_balance()
		_record_home_composite_result(true)
		_update_coin_label()
		_update_home()
		board.play_victory()
		audio_controller.play_victory()
		_save_game()
		await get_tree().create_timer(board.victory_result_delay()).timeout
		_prepare_success_result_page(composite_reward)
		result_page.show_animated()
		return
	var level_id := int(current_level["levelId"])
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
	var result: Dictionary = RunResultServiceScript.formal_completion(player_level_number, current_heart_limit, heart_count)
	var reward := int(result["reward"])
	player_wallet.grant(reward, "formal_completion")
	CoinEconomyScript.record_completion(
		economy_progress,
		level_id,
		player_level_number,
		int(current_level.get("rows", 5)),
		current_heart_limit,
		heart_count,
		reward,
		run_coin_exchange_count
	)
	_record_level_result()
	_update_coin_label()
	_update_home()
	board.play_victory()
	audio_controller.play_victory()
	_save_game()
	await get_tree().create_timer(board.victory_result_delay()).timeout
	_prepare_success_result_page(reward)
	result_page.show_animated()


func _prepare_success_result_page(reward: int = 0) -> void:
	_set_result_overlay_mode("success")
	var excellent := not home_composite_entry_active and CoinRewardPolicyScript.is_excellent_completion(current_heart_limit, heart_count)
	if reward <= 0:
		if home_composite_entry_active:
			reward = int(active_schedule.get("compositeCoinReward", CompositeCoinPolicyScript.base_reward_for_round(home_composite_round)))
		else:
			reward = CoinRewardPolicyScript.completion_reward(player_level_number, current_heart_limit, heart_count)
	var next_quote := _home_composite_round_quote(home_composite_round + 1) if home_composite_entry_active else {}
	result_page.present_success({
		"excellent": excellent,
		"composite": home_composite_entry_active,
		"round": home_composite_round,
		"displayLevel": player_level_number,
		"reward": reward,
		"coinBalance": coin_count,
		"entryCost": int(active_schedule.get("compositeEntryCost", 0)),
		"paidEntry": bool(active_schedule.get("compositePaidEntry", false)),
		"nextPaid": bool(next_quote.get("paid", false)),
		"nextEntryCost": int(next_quote.get("entryCost", 0))
	})


func _prepare_failure_result_page() -> void:
	_set_result_overlay_mode("failure")
	result_page.present_failure({
		"composite": home_composite_entry_active,
		"round": home_composite_round,
		"displayLevel": player_level_number,
		"revivePrice": _current_tool_price(CoinEconomyScript.TOOL_REVIVE)
	})


func _show_composite_deadlock() -> void:
	if not _is_assembly_phase() or not composite_deadlocked:
		return
	_set_result_overlay_mode("assembly_deadlock")
	audio_controller.play_block_deadlock()
	assembly_view.input_locked = true
	result_page.present_deadlock(_current_tool_price(CoinEconomyScript.TOOL_REVIVE))
	result_page.show_animated()


func _record_level_result() -> void:
	_sync_director_completed_levels()
	RunResultServiceScript.record_formal(true, director_progress, current_level, active_schedule, _run_result_context())
	_sync_director_completed_levels()


func _record_level_failure() -> void:
	_sync_director_completed_levels()
	RunResultServiceScript.record_formal(false, director_progress, current_level, active_schedule, _run_result_context())
	_sync_director_completed_levels()


func _record_home_composite_result(completed: bool) -> void:
	RunResultServiceScript.record_composite(
		composite_director_progress, current_level, active_schedule, completed, _run_result_context()
	)


func _run_result_context() -> Dictionary:
	return {
		"startedUnix": run_started_unix,
		"finishedUnix": int(Time.get_unix_time_from_system()),
		"moveCount": run_move_count,
		"hintCount": run_hint_count,
		"directFindCount": run_direct_find_count,
		"today": _today_string()
	}


func _next_level() -> void:
	if in_tutorial:
		_next_tutorial_step()
		return
	player_level_number += 1
	var next_schedule := LevelDirectorScript.schedule_for_display_level(levels, player_level_number, director_progress)
	var next_index := int(next_schedule.get("levelIndex", 0))
	_load_level(next_index, false, next_schedule)
	LevelDirectorScript.record_next_level_opened(director_progress)
	_save_game()
	if bool(next_schedule.get("isMilestoneChallenge", false)):
		_show_toast("难度挑战：本关根据最近表现安排")


func _completion_primary_pressed() -> void:
	if result_overlay_mode == "assembly_deadlock":
		_revive_composite_deadlock()
		return
	if home_composite_entry_active:
		completion_overlay.hide()
		if result_overlay_mode == "success":
			_start_next_home_composite_round()
		else:
			_replay_level()
			_show_game()
		return
	match result_overlay_mode:
		"tutorial":
			_next_level()
		"failure":
			_revive_current_level()
		_:
			_next_level()


func _completion_secondary_pressed() -> void:
	if result_overlay_mode == "assembly_deadlock":
		_restart_composite_round_from_deadlock()
		return
	if home_composite_entry_active:
		completion_overlay.hide()
		_show_home()
		return
	if result_overlay_mode == "failure":
		completion_overlay.hide()
		_replay_level()
	elif result_overlay_mode == "success":
		completion_overlay.hide()
		_show_home()
		_save_game()
	else:
		_replay_level()


func _revive_current_level() -> void:
	if not is_failed:
		return
	if not _spend_coins_for_tool(CoinEconomyScript.TOOL_REVIVE):
		return
	is_failed = false
	heart_count = 1
	completion_overlay.hide()
	if hint_button:
		hint_button.disabled = false
	_update_heart_label()
	_validate_and_update(false)
	_update_hint_button()
	_update_crown_find_button()
	_save_game()
	_show_toast("复活成功：保留棋盘并恢复 1 颗红心")


func _revive_composite_deadlock() -> void:
	if not _is_assembly_phase() or not composite_deadlocked or composite_placement_history.is_empty():
		return
	if not _spend_coins_for_tool(CoinEconomyScript.TOOL_REVIVE):
		return
	var revive_result: Dictionary = composite_controller.revive_last_placement()
	var returned_slot := int(revive_result.get("slot", -1))
	completion_overlay.hide()
	assembly_view.input_locked = false
	assembly_view.update_state(composite_placements, _assembly_allowed_origins(), composite_tray_slots)
	if returned_slot >= 0:
		audio_controller.play_block_revive()
		assembly_view.focus_tray_slot(returned_slot)
	_save_game()
	_show_toast("复活成功：最后一个方块已放回托盘")


func _restart_composite_round_from_deadlock() -> void:
	if not _is_assembly_phase():
		return
	composite_deadlocked = false
	completion_overlay.hide()
	_replay_level()
	_show_game()


func _replay_level() -> void:
	if in_tutorial:
		_start_tutorial_step(tutorial_step_index)
		return
	_load_level(current_level_index, false, active_schedule)


func _on_settings() -> void:
	if not dialog_controller or not language_picker:
		return
	_refresh_language_picker()
	dialog_controller.show_dialog(
		"settings",
		"游戏设置",
		"",
		"settings",
		[
			{"id": "cancel", "text": "取消", "variant": "secondary"},
			{"id": "apply", "text": "应用", "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		true
	)


func _on_help() -> void:
	if not dialog_controller:
		return
	if help_content:
		help_content.show_composite_tab(_is_assembly_phase())
	dialog_controller.show_dialog(
		"help",
		"玩法帮助" if _is_assembly_phase() else "消除规则",
		"",
		"help_rules",
		[{"id": "close", "text": "知道了", "variant": "primary"}],
		UITokensScript.DIALOG_RICH_WIDTH,
		true
	)


func _replay_composite_intro_from_help() -> void:
	if not _is_assembly_phase() or not assembly_view:
		_show_toast("进入拼块阶段后可以重播演示")
		return
	dialog_controller.hide_dialog(true)
	composite_intro_marks_seen = false
	composite_intro_running = true
	assembly_view.play_intro()


func _show_tutorial_resume_dialog() -> void:
	if not dialog_controller:
		return
	dialog_controller.show_dialog(
		"tutorial_resume",
		"继续新手教程？",
		"检测到你还没有完成新手教程。",
		"",
		[
			{"id": "restart", "text": "重新开始", "variant": "secondary"},
			{"id": "continue", "text": "继续教程", "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		false
	)


func _on_dialog_action_selected(dialog_id: String, action_id: String) -> void:
	match dialog_id:
		"level_select":
			if action_id == "enter":
				_confirm_level_select()
		"tutorial_skip":
			if action_id == "skip":
				_finish_tutorial(true)
		"tutorial_resume":
			if action_id == "continue":
				_start_tutorial_step(tutorial_step_index)
			elif action_id == "restart":
				_start_tutorial_step(0)
		"coin_shortage":
			if action_id == "rewarded":
				_show_toast("激励广告入口占位：SDK 回调成功后发放 %d 金币" % pending_rewarded_coin_grant)
			elif action_id == "purchase":
				_show_toast("金币购买入口占位：接入支付后开放")
		"settings":
			if action_id == "apply":
				_apply_selected_settings()


func _on_dialog_cancelled(dialog_id: String) -> void:
	if dialog_id == "tutorial_resume":
		_start_tutorial_step(0)


func _refresh_language_picker() -> void:
	if not settings_content or not localization:
		return
	settings_content.present(
		localization.language_options(),
		localization.locale_index(selected_language),
		{
			"musicEnabled": music_enabled,
			"sfxEnabled": sfx_enabled,
			"hapticsEnabled": haptics_enabled,
		}
	)


func _apply_selected_language() -> void:
	_apply_selected_settings()


func _apply_selected_settings() -> void:
	if not settings_content:
		return
	var locale: String = settings_content.selected_locale()
	if not locale.is_empty():
		localization.set_locale(locale)
		selected_language = localization.current_locale
	var preferences: Dictionary = settings_content.selected_audio_preferences()
	music_enabled = bool(preferences.get("musicEnabled", true))
	sfx_enabled = bool(preferences.get("sfxEnabled", true))
	haptics_enabled = bool(preferences.get("hapticsEnabled", true))
	if audio_controller:
		audio_controller.set_audio_preferences(music_enabled, sfx_enabled, haptics_enabled)
	for page in [formal_level_page, composite_level_page]:
		if page and page.board:
			page.board.set_haptics_enabled(haptics_enabled)
	_save_game()


func _on_locale_changed(locale: String) -> void:
	selected_language = locale
	_apply_layout_direction()
	_refresh_localized_ui()


func _apply_layout_direction() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if localization and localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR


func _refresh_localized_ui() -> void:
	localization.localize_tree(self)
	_update_home()
	_update_hint_button()
	_update_crown_find_button()
	_update_tutorial_button()
	if home_screen:
		home_screen.refresh_localized_text()
	if help_content:
		help_content.refresh_localized_text()
	if in_tutorial:
		level_label.text = _t("新手教程")
		_update_tutorial_action_bar()
	elif not current_level.is_empty():
		level_label.text = _display_level_title()
		coach_label.text = _level_coach_text()
		if _is_assembly_phase() and assembly_stage_label:
			assembly_stage_label.text = str(composite_data.get("difficulty", "medium")).to_upper()
	if completion_overlay and completion_overlay.visible:
		if result_overlay_mode == "success":
			_prepare_success_result_page()
		elif result_overlay_mode == "failure":
			_prepare_failure_result_page()


func _open_level_select() -> void:
	if not debug_level_selection_enabled or not level_select_content or not level_select_picker:
		return
	if in_tutorial:
		_show_toast("完成新手教程后即可选择关卡")
		return
	_refresh_level_select_picker()
	level_select_picker.select(current_level_index)
	dialog_controller.show_dialog(
		"level_select",
		"关卡选择",
		"",
		"level_select",
		[
			{"id": "cancel", "text": "取消", "variant": "secondary"},
			{"id": "enter", "text": "进入关卡", "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		true
	)


func _refresh_level_select_picker() -> void:
	if not level_select_content:
		return
	level_select_content.present(levels, completed_levels, current_level_index)


func _confirm_level_select() -> void:
	if not debug_level_selection_enabled or not level_select_content:
		return
	var selected_index: int = level_select_content.selected_index()
	selected_index = clampi(selected_index, 0, levels.size() - 1)
	tutorial_completed = true
	tutorial_started = false
	tutorial_step_index = 0
	_load_level(selected_index)
	_show_game()
	_save_game()
	_show_toast(_t("已进入关卡 %d", [int(current_level["levelId"])]))


func _is_solution_cell(row: int, col: int) -> bool:
	return CrownRuleEngineScript.is_solution_cell(current_level, Vector2i(col, row))


func _push_history() -> void:
	formal_controller.push_history(cell_states)


func _blank_states(rows: int, cols: int) -> Array:
	return GameSaveServiceScript.blank_states(rows, cols)


func _states_match_size(states: Array, rows: int, cols: int) -> bool:
	return GameSaveServiceScript.states_match_size(states, rows, cols)


func _today_string() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


func _load_save() -> void:
	var data: Dictionary = GameSaveServiceScript.normalize_loaded(
		save_repository.load_data(),
		{
			"coinCount": INITIAL_COIN_COUNT,
			"hintCount": INITIAL_HINT_COUNT,
			"crownFindCount": INITIAL_CROWN_FIND_COUNT,
			"heartCount": INITIAL_HEART_COUNT
		},
		_today_string()
	)
	if data.is_empty():
		return
	current_level_index = int(data.get("currentLevelIndex", 0))
	player_level_number = maxi(1, int(data.get("playerLevelNumber", current_level_index + 1)))
	coin_count = int(data.get("coinCount", INITIAL_COIN_COUNT))
	hint_count = maxi(0, int(data.get("hintCount", INITIAL_HINT_COUNT)))
	crown_find_count = clampi(int(data.get("crownFindCount", INITIAL_CROWN_FIND_COUNT)), 0, INITIAL_CROWN_FIND_COUNT)
	completed_levels.assign(data.get("completedLevels", []))
	heart_count = maxi(0, int(data.get("heartCount", INITIAL_HEART_COUNT)))
	resume_level_id = int(data.get("currentLevelId", -1))
	resume_states = data.get("cellStates", [])
	resume_completed = bool(data.get("isCompleted", false))
	resume_failed = bool(data.get("isFailed", false))
	active_schedule = data["activeSchedule"]
	director_progress = data["directorProgress"]
	composite_director_progress = data["compositeDirectorProgress"]
	composite_coin_progress = data["compositeCoinProgress"]
	economy_progress = data["economyProgress"]
	run_started_unix = int(data.get("runStartedUnix", 0))
	run_move_count = int(data.get("runMoveCount", 0))
	run_hint_count = int(data.get("runHintCount", 0))
	run_direct_find_count = int(data.get("runDirectFindCount", 0))
	run_coin_exchange_count = maxi(0, int(data.get("runCoinExchangeCount", 0)))
	immediate_errors = bool(data.get("immediateErrors", true))
	selected_language = str(data.get("selectedLanguage", ""))
	music_enabled = bool(data.get("musicEnabled", true))
	sfx_enabled = bool(data.get("sfxEnabled", true))
	haptics_enabled = bool(data.get("hapticsEnabled", true))
	tutorial_controller.restore(data, TUTORIAL_LEVELS.size())
	formal_progress_snapshot = data["formalProgressSnapshot"]
	home_composite_entry_active = bool(data.get("homeCompositeEntryActive", false))
	home_composite_round = maxi(0, int(data.get("homeCompositeRound", 0)))
	home_composite_progress_snapshot = data["homeCompositeProgressSnapshot"]
	home_composite_history = data["homeCompositeHistory"]
	resume_composite_state = data["compositeState"]
	composite_tutorial_seen = bool(data.get("compositeTutorialSeen", false))


func _capture_formal_progress_snapshot() -> bool:
	if in_tutorial or current_level.is_empty() or int(current_level.get("levelId", -1)) < 0:
		return false
	formal_progress_snapshot = GameSaveServiceScript.capture_formal({
		"currentLevelIndex": current_level_index,
		"currentLevelId": int(current_level["levelId"]),
		"playerLevelNumber": player_level_number,
		"activeSchedule": active_schedule.duplicate(true),
		"directorProgress": director_progress.duplicate(true),
		"economyProgress": economy_progress.duplicate(true),
		"completedLevels": completed_levels.duplicate(),
		"cellStates": cell_states.duplicate(true),
		"isCompleted": is_completed,
		"isFailed": is_failed,
		"coinCount": coin_count,
		"heartCount": heart_count,
		"hintCount": hint_count,
		"crownFindCount": crown_find_count,
		"runStartedUnix": run_started_unix,
		"runMoveCount": run_move_count,
		"runHintCount": run_hint_count,
		"runDirectFindCount": run_direct_find_count,
		"runCoinExchangeCount": run_coin_exchange_count,
		"compositeTutorialSeen": composite_tutorial_seen
	}, _composite_save_state())
	return true


func _formal_progress_snapshot_is_valid(snapshot: Dictionary) -> bool:
	return GameSaveServiceScript.formal_snapshot_is_valid(snapshot, levels)


func _restore_formal_progress_snapshot() -> bool:
	var snapshot := formal_progress_snapshot.duplicate(true)
	if not _formal_progress_snapshot_is_valid(snapshot):
		formal_progress_snapshot.clear()
		return false
	current_level_index = int(snapshot["currentLevelIndex"])
	player_level_number = maxi(1, int(snapshot.get("playerLevelNumber", current_level_index + 1)))
	var snapshot_schedule = snapshot.get("activeSchedule", {})
	active_schedule = snapshot_schedule.duplicate(true) if snapshot_schedule is Dictionary else {}
	var snapshot_progress = snapshot.get("directorProgress", {})
	director_progress = snapshot_progress.duplicate(true) if snapshot_progress is Dictionary else {}
	LevelDirectorScript.normalize_progress(director_progress)
	var snapshot_economy = snapshot.get("economyProgress", {})
	economy_progress = snapshot_economy.duplicate(true) if snapshot_economy is Dictionary else CoinEconomyScript.default_progress()
	CoinEconomyScript.normalize_progress(economy_progress)
	completed_levels.assign(snapshot.get("completedLevels", []))
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	resume_level_id = int(snapshot["currentLevelId"])
	resume_states = snapshot["cellStates"].duplicate(true)
	resume_completed = bool(snapshot.get("isCompleted", false))
	resume_failed = bool(snapshot.get("isFailed", false))
	coin_count = int(snapshot.get("coinCount", coin_count))
	heart_count = maxi(0, int(snapshot.get("heartCount", INITIAL_HEART_COUNT)))
	hint_count = maxi(0, int(snapshot.get("hintCount", hint_count)))
	crown_find_count = clampi(int(snapshot.get("crownFindCount", crown_find_count)), 0, INITIAL_CROWN_FIND_COUNT)
	run_started_unix = int(snapshot.get("runStartedUnix", 0))
	run_move_count = maxi(0, int(snapshot.get("runMoveCount", 0)))
	run_hint_count = maxi(0, int(snapshot.get("runHintCount", 0)))
	run_direct_find_count = maxi(0, int(snapshot.get("runDirectFindCount", 0)))
	run_coin_exchange_count = maxi(0, int(snapshot.get("runCoinExchangeCount", 0)))
	var snapshot_composite = snapshot.get("compositeState", {})
	resume_composite_state = snapshot_composite.duplicate(true) if snapshot_composite is Dictionary else {}
	composite_tutorial_seen = bool(snapshot.get("compositeTutorialSeen", composite_tutorial_seen))
	formal_progress_snapshot.clear()
	_load_level(current_level_index, true, active_schedule, true)
	return true


func _restore_home_composite_progress() -> bool:
	var snapshot := home_composite_progress_snapshot.duplicate(true)
	if not _formal_progress_snapshot_is_valid(snapshot):
		home_composite_progress_snapshot.clear()
		home_composite_entry_active = false
		home_composite_round = 0
		return false
	var preserved_tutorial_snapshot := formal_progress_snapshot.duplicate(true)
	var tutorial_seen_in_entry := composite_tutorial_seen
	formal_progress_snapshot = snapshot
	home_composite_progress_snapshot.clear()
	home_composite_entry_active = false
	home_composite_round = 0
	composite_intro_running = false
	composite_intro_marks_seen = false
	var restored := _restore_formal_progress_snapshot()
	formal_progress_snapshot = preserved_tutorial_snapshot
	composite_tutorial_seen = composite_tutorial_seen or tutorial_seen_in_entry
	return restored


func _update_home_composite_history() -> void:
	if not home_composite_entry_active or not composite_mode or current_level.is_empty():
		return
	home_composite_history = GameSaveServiceScript.build_home_composite_history({
		"round": maxi(1, home_composite_round),
		"levelIndex": current_level_index,
		"levelId": int(current_level.get("levelId", -1)),
		"activeSchedule": active_schedule,
		"cellStates": cell_states.duplicate(true),
		"isCompleted": is_completed,
		"isFailed": is_failed,
		"heartCount": heart_count,
		"hintCount": hint_count,
		"crownFindCount": crown_find_count,
		"runStartedUnix": run_started_unix,
		"runMoveCount": run_move_count,
		"runHintCount": run_hint_count,
		"runDirectFindCount": run_direct_find_count,
		"runCoinExchangeCount": run_coin_exchange_count
	}, _composite_save_state())


func _home_composite_history_is_valid(history: Dictionary) -> bool:
	return GameSaveServiceScript.home_composite_history_is_valid(history, levels)


func _home_composite_resume_round() -> int:
	if not _home_composite_history_is_valid(home_composite_history):
		return 1
	var saved_round := maxi(1, int(home_composite_history.get("round", 1)))
	return saved_round + 1 if bool(home_composite_history.get("isCompleted", false)) else saved_round


func _save_game() -> void:
	if current_level.is_empty():
		return
	_update_home_composite_history()
	_sync_director_completed_levels()
	var data := GameSaveServiceScript.build_save({
		"saveVersion": SAVE_VERSION,
		"currentLevelIndex": current_level_index,
		"currentLevelId": int(current_level["levelId"]),
		"playerLevelNumber": player_level_number,
		"activeSchedule": active_schedule,
		"directorProgress": director_progress,
		"compositeDirectorProgress": composite_director_progress,
		"compositeCoinProgress": composite_coin_progress,
		"economyProgress": economy_progress,
		"runStartedUnix": run_started_unix,
		"runMoveCount": run_move_count,
		"runHintCount": run_hint_count,
		"runDirectFindCount": run_direct_find_count,
		"runCoinExchangeCount": run_coin_exchange_count,
		"coinCount": coin_count,
		"heartCount": heart_count,
		"crownFindCount": crown_find_count,
		"completedLevels": completed_levels,
		"selectedTheme": "crown",
		"hintCount": hint_count,
		"immediateErrors": immediate_errors,
		"selectedLanguage": selected_language,
		"musicEnabled": music_enabled,
		"sfxEnabled": sfx_enabled,
		"hapticsEnabled": haptics_enabled,
		"isCompleted": is_completed,
		"isFailed": is_failed,
		"cellStates": cell_states,
		"formalProgressSnapshot": formal_progress_snapshot,
		"homeCompositeEntryActive": home_composite_entry_active,
		"homeCompositeRound": home_composite_round,
		"homeCompositeProgressSnapshot": home_composite_progress_snapshot,
		"homeCompositeHistory": home_composite_history,
		"compositeTutorialSeen": composite_tutorial_seen
	}, tutorial_controller, _composite_save_state())
	resume_composite_state = data["compositeState"].duplicate(true)
	save_repository.save_data(data)


func _queue_save_game_after_frame() -> void:
	if save_game_after_frame_pending:
		return
	save_game_after_frame_pending = true
	call_deferred("_flush_save_game_after_frame")


func _flush_save_game_after_frame() -> void:
	await get_tree().process_frame
	save_game_after_frame_pending = false
	_save_game()


func _update_coin_label() -> void:
	if game_screen:
		game_screen.set_coin_balance(coin_count)


func _play_coin_deduction_animation(balance_before: int, balance_after: int, amount: int) -> void:
	if game_screen:
		game_screen.play_coin_deduction(balance_before, balance_after, amount)


func _update_heart_label() -> void:
	if game_screen:
		game_screen.set_hearts(heart_count, current_heart_limit)


func _stop_heart_tweens() -> void:
	if formal_level_page:
		formal_level_page.stop_heart_animation()
	if composite_level_page:
		composite_level_page.stop_heart_animation()


func _heart_limit_for_display_level(display_level: int) -> int:
	if display_level <= 10:
		return 3
	if display_level <= 30:
		return 2
	return 1


func _consume_heart_for_wrong_crown() -> void:
	if heart_count > 0:
		heart_count -= 1
	_update_heart_label()
	_update_home()
	if heart_count <= 0:
		_fail_level()
	else:
		_show_toast("皇冠位置错误，红心 -1")


func _fail_level() -> void:
	if is_completed or is_failed:
		return
	is_failed = true
	if home_composite_entry_active:
		_record_home_composite_result(false)
	elif not _is_assembly_phase():
		_record_level_failure()
	hint_engine.reset_session()
	board.set_guides({})
	if game_screen:
		game_screen.present_tool("hint", {"label": "提示", "status": "free_forever", "disabled": true})
		game_screen.present_tool("crown", {"label": "直找", "status": "free_forever", "disabled": true})
		game_screen.present_tool("clear", {"label": "清除", "status": "free_forever", "disabled": true})
	coach_label.text = _t("红心已用完，本关挑战失败。")
	coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
	_prepare_failure_result_page()
	_save_game()
	completion_overlay.show()
	completion_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(completion_overlay, "modulate:a", 1.0, 0.2)


func _update_hint_button() -> void:
	if not game_screen:
		return
	if _is_assembly_phase():
		_update_assembly_tool_buttons()
		return
	if in_tutorial:
		game_screen.present_tool("hint", {
			"label": "提示",
			"status": "tutorial",
			"disabled": tutorial_interaction_stage != TUTORIAL_PHASE_HINT
		})
		return
	var hint_price := _current_tool_price(CoinEconomyScript.TOOL_HINT)
	game_screen.present_tool("hint", {
		"label": "提示",
		"status": _hint_tool_status(),
		"value": hint_count if hint_count > 0 else hint_price,
		"disabled": is_completed or is_failed or _is_assembly_phase()
	})


func _hint_tool_status() -> String:
	return "free" if hint_count > 0 else "paid"


func _update_crown_find_button() -> void:
	if not game_screen:
		return
	if _is_assembly_phase():
		_update_assembly_tool_buttons()
		return
	if in_tutorial:
		game_screen.present_tool("crown", {
			"label": "皇冠直找",
			"status": "tutorial",
			"disabled": tutorial_interaction_stage != TUTORIAL_PHASE_CROWN_FIND
		})
		return
	var has_target := not current_level.is_empty() and _next_findable_solution_cell().x >= 0
	game_screen.present_tool("crown", {
		"label": "直找",
		"status": "free" if crown_find_count > 0 else "paid",
		"value": crown_find_count if crown_find_count > 0 else _current_tool_price(CoinEconomyScript.TOOL_CROWN_FIND),
		"disabled": is_completed or is_failed or not has_target
	})


func _update_level_picker() -> void:
	if level_picker and level_picker.selected != current_level_index:
		level_picker.select(current_level_index)


func _show_home() -> void:
	_hide_tutorial_hand()
	_cancel_opening_king_intro(false)
	result_page.stop_lion_animation()
	result_page.stop_petals()
	_stop_heart_tweens()
	if home_composite_entry_active:
		_update_home_composite_history()
		_restore_home_composite_progress()
		_save_game()
	# Restoring the formal snapshot can schedule its opening kings again. Home
	# must always finish with that transient overlay and pending reveal cleared.
	_cancel_opening_king_intro(false)
	if home_screen:
		home_screen.show()
	if game_screen:
		game_screen.hide()
	if completion_overlay:
		completion_overlay.hide()
	_update_home()


func _start_current_flow() -> void:
	if tutorial_completed:
		if is_completed:
			_next_level()
		_show_game()
	elif tutorial_started:
		_show_tutorial_resume_dialog()
	else:
		_start_tutorial_step(0)


func _start_home_composite_flow() -> void:
	if not tutorial_completed:
		_start_current_flow()
		return
	if not _home_composite_is_unlocked():
		_show_home_composite_locked_dialog()
		return
	var history := home_composite_history.duplicate(true)
	var can_resume_history := _home_composite_history_is_valid(history) and not bool(history.get("isCompleted", false))
	var target_round := _home_composite_resume_round()
	var candidate: Dictionary = {}
	var round_quote: Dictionary = {}
	if not can_resume_history:
		round_quote = _home_composite_round_quote(target_round)
		if not CompositeEntryServiceScript.can_afford(round_quote, coin_count):
			_show_home_composite_coin_shortage(round_quote)
			return
		candidate = _home_composite_candidate(target_round)
		if candidate.is_empty():
			_show_toast("暂时没有可用的拼块关卡")
			return
	if not _capture_formal_progress_snapshot():
		_show_toast("当前关卡现场暂时无法保存")
		return
	home_composite_progress_snapshot = formal_progress_snapshot.duplicate(true)
	formal_progress_snapshot.clear()
	home_composite_entry_active = true
	if can_resume_history:
		home_composite_round = maxi(1, int(history.get("round", 1)))
		resume_level_id = int(history.get("levelId", -1))
		resume_states = history.get("cellStates", []).duplicate(true)
		resume_completed = bool(history.get("isCompleted", false))
		resume_failed = bool(history.get("isFailed", false))
		heart_count = maxi(0, int(history.get("heartCount", INITIAL_HEART_COUNT)))
		hint_count = maxi(0, int(history.get("hintCount", hint_count)))
		crown_find_count = clampi(int(history.get("crownFindCount", crown_find_count)), 0, INITIAL_CROWN_FIND_COUNT)
		run_started_unix = int(history.get("runStartedUnix", 0))
		run_move_count = maxi(0, int(history.get("runMoveCount", 0)))
		run_hint_count = maxi(0, int(history.get("runHintCount", 0)))
		run_direct_find_count = maxi(0, int(history.get("runDirectFindCount", 0)))
		run_coin_exchange_count = maxi(0, int(history.get("runCoinExchangeCount", 0)))
		var saved_composite = history.get("compositeState", {})
		resume_composite_state = saved_composite.duplicate(true) if saved_composite is Dictionary else {}
		var saved_schedule = history.get("activeSchedule", {})
		var schedule: Dictionary = saved_schedule.duplicate(true) if saved_schedule is Dictionary else {}
		_load_level(int(history.get("levelIndex", 0)), true, schedule, true)
	else:
		home_composite_round = target_round
		resume_level_id = -1
		resume_states.clear()
		resume_completed = false
		resume_failed = false
		resume_composite_state.clear()
		var schedule := _home_composite_schedule_with_coin_quote(candidate["schedule"], round_quote)
		_load_level(int(candidate["levelIndex"]), false, schedule)
	if not composite_mode:
		_restore_home_composite_progress()
		_show_toast("拼块关卡加载失败，请重试")
		return
	if not can_resume_history:
		_apply_home_composite_round_entry(round_quote)
	_show_game()
	_save_game()


func _start_next_home_composite_round() -> void:
	var next_round := home_composite_round + 1
	var round_quote := _home_composite_round_quote(next_round)
	if not CompositeEntryServiceScript.can_afford(round_quote, coin_count):
		_show_home_composite_coin_shortage(round_quote)
		completion_overlay.show()
		return
	var candidate := _home_composite_candidate(next_round)
	if candidate.is_empty():
		_show_toast("下一局生成失败，请重试")
		completion_overlay.show()
		return
	home_composite_round = next_round
	resume_level_id = -1
	resume_states.clear()
	resume_composite_state.clear()
	var schedule := _home_composite_schedule_with_coin_quote(candidate["schedule"], round_quote)
	_load_level(int(candidate["levelIndex"]), false, schedule)
	if not _is_assembly_phase():
		home_composite_round -= 1
		_show_toast("下一局生成失败，请重试")
		completion_overlay.show()
		return
	_apply_home_composite_round_entry(round_quote)
	_show_game()
	_save_game()


func _home_composite_round_quote(round_number: int) -> Dictionary:
	return CompositeEntryServiceScript.quote(round_number, composite_coin_progress, _today_string())


func _home_composite_schedule_with_coin_quote(raw_schedule: Dictionary, quote: Dictionary) -> Dictionary:
	return CompositeEntryServiceScript.schedule_with_quote(raw_schedule, quote)


func _apply_home_composite_round_entry(quote: Dictionary) -> void:
	var transaction: Dictionary = CompositeEntryServiceScript.apply_entry(
		quote, player_wallet, composite_coin_progress, _today_string()
	)
	if not bool(transaction.get("success", false)):
		return
	var entry_cost := int(transaction.get("amount", 0))
	_sync_home_composite_shared_coin_balance()
	_update_coin_label()
	_update_home()
	if entry_cost > 0:
		call_deferred(
			"_play_coin_deduction_animation",
			int(transaction.get("balanceBefore", coin_count)),
			int(transaction.get("balanceAfter", coin_count)),
			entry_cost
		)
		_show_toast(_t("拼块入场 -%d 金币", [entry_cost]))


func _sync_home_composite_shared_coin_balance() -> void:
	if not home_composite_progress_snapshot.is_empty():
		home_composite_progress_snapshot["coinCount"] = coin_count


func _show_home_composite_coin_shortage(quote: Dictionary) -> void:
	var entry_cost := int(quote.get("entryCost", 0))
	var reward := int(quote.get("reward", 0))
	dialog_controller.show_dialog(
		"home_composite_coin_shortage",
		_t("金币不足"),
		_t("今日免费拼块次数已用完。本局需要 %d 金币，完成后可获得 %d 金币。", [entry_cost, reward]),
		"",
		[{"id": "confirm", "text": _t("知道了"), "variant": "primary"}],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		false
	)


func _home_composite_candidate(round_number: int = 1) -> Dictionary:
	var formal_display := int(home_composite_progress_snapshot.get("playerLevelNumber", player_level_number))
	return CompositeLevelDirectorScript.recommend(
		levels,
		composite_levels,
		maxi(1, round_number),
		maxi(1, formal_display),
		composite_director_progress
	)


func _home_composite_unlock_display_level() -> int:
	return CompositeEntryServiceScript.unlock_display_level()


func _home_composite_formal_display_level() -> int:
	if home_composite_entry_active and not home_composite_progress_snapshot.is_empty():
		return maxi(1, int(home_composite_progress_snapshot.get("playerLevelNumber", player_level_number)))
	return maxi(1, player_level_number)


func _home_composite_is_unlocked() -> bool:
	return CompositeEntryServiceScript.is_unlocked(_home_composite_formal_display_level())


func _show_home_composite_locked_dialog() -> void:
	var unlock_display := _home_composite_unlock_display_level()
	dialog_controller.show_dialog(
		"home_composite_locked",
		_t("拼块玩法尚未解锁"),
		_t("玩到第 %d 关，即可解锁 6×6 拼块玩法。", [unlock_display]),
		"",
		[{"id": "confirm", "text": _t("知道了"), "variant": "primary"}],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		false
	)


func _replay_tutorial_preserving_progress() -> void:
	_capture_formal_progress_snapshot()
	tutorial_controller.reset_for_replay()
	completion_overlay.hide()
	_start_tutorial_step(0)
	_show_toast("已进入新手教程，正式关卡进度已保存")


func _simulate_new_user_flow() -> void:
	_replay_tutorial_preserving_progress()


func _show_game() -> void:
	if home_screen:
		home_screen.hide()
	if game_screen:
		game_screen.show()
	_update_tutorial_button()
	if board:
		board.queue_redraw()
	if _is_assembly_phase():
		_apply_composite_phase_ui()
		call_deferred("_maybe_play_composite_intro")
	else:
		_play_pending_opening_king_reveal()


func _update_tutorial_button() -> void:
	if not tutorial_skip_button:
		return
	if in_tutorial:
		tutorial_skip_button.text = _t("跳过")
		tutorial_skip_button.tooltip_text = _t("跳过新手教程")
		tutorial_skip_button.show()
	else:
		tutorial_skip_button.hide()
	if top_home_button:
		top_home_button.show()
	if level_select_button:
		level_select_button.visible = debug_level_selection_enabled and not in_tutorial and not home_composite_entry_active
	if help_button:
		help_button.show()
	if level_heart_label:
		level_heart_label.show()
	if in_tutorial:
		_stop_heart_tweens()
	else:
		_update_heart_label()
	if crown_find_button:
		crown_find_button.visible = not _is_assembly_phase()
	if clear_button:
		clear_button.visible = not _is_assembly_phase()
	if hint_button:
		hint_button.visible = not _is_assembly_phase()


func _update_home() -> void:
	if not home_screen or levels.is_empty():
		return
	var saved_round := _home_composite_resume_round()
	var has_unfinished_round := _home_composite_history_is_valid(home_composite_history) and not bool(home_composite_history.get("isCompleted", false))
	var quote := _home_composite_round_quote(saved_round)
	home_screen.present({
		"tutorial_completed": tutorial_completed,
		"tutorial_started": tutorial_started,
		"player_level": player_level_number,
		"composite_unlocked": _home_composite_is_unlocked(),
		"composite_unlock_level": _home_composite_unlock_display_level(),
		"composite_round": saved_round,
		"composite_has_history": not home_composite_history.is_empty(),
		"composite_paid": not has_unfinished_round and bool(quote.get("paid", false)),
		"composite_entry_cost": int(quote.get("entryCost", 0)),
	})


func _show_toast(message: String) -> void:
	if feedback_layer:
		feedback_layer.show_toast(_runtime_text(message))


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)


func _t(source: String, values: Array = []) -> String:
	if not localization:
		return source % values if not values.is_empty() else source
	return localization.text(source, values)


func _runtime_text(source: String, generic_source: String = "请跟随高亮提示继续操作。") -> String:
	if not localization:
		return source
	return localization.runtime_text(source, generic_source)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_H:
				_use_hint()
