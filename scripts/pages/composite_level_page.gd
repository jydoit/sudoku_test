extends "res://scripts/pages/level_page_base.gd"


func configure(initial_coins: int, localizer: Callable, enable_level_select: bool = true) -> void:
	setup(initial_coins, true, localizer, enable_level_select)
