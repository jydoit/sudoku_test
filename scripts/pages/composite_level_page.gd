extends "res://scripts/pages/level_page_base.gd"


func configure(initial_coins: int, localizer: Callable) -> void:
	setup(initial_coins, true, localizer)
