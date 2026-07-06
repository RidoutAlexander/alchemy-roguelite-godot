class_name GoldRewardDisplay
extends GoldDisplay


func _ready() -> void:
	super._ready()
	show_plus_prefix = true
	GameManager.brew_updated.connect(_on_brew_updated)
	GameManager.brew_stats_presented.connect(_on_brew_stats_presented)
	GameManager.run_changed.connect(_refresh)
	_refresh()


func _on_brew_updated(_ctx: BrewContext) -> void:
	_refresh()


func _on_brew_stats_presented(_ctx: BrewContext) -> void:
	_refresh()


func _refresh() -> void:
	if GameManager.run == null or GameManager.run.brew_session == null:
		set_amount(0)
		return
	set_amount(GameManager.run.brew_session.calculate_display_gold_reward())