@tool
class_name LivesDisplay
extends Control

@export var icon_texture: Texture2D = preload("res://assets/sprites/lives_icon.png"):
	set(value):
		icon_texture = value
		_queue_editor_refresh()

@export var empty_icon_texture: Texture2D = preload("res://assets/sprites/lives_icon_empty.png"):
	set(value):
		empty_icon_texture = value
		_queue_editor_refresh()

@export var icon_size: Vector2 = Vector2(48, 48):
	set(value):
		icon_size = value
		_queue_editor_refresh()

@export var icon_spacing: int = 6:
	set(value):
		icon_spacing = value
		_queue_editor_refresh()

@export var max_lives_shown: int = GameConstants.MAX_LIVES:
	set(value):
		max_lives_shown = value
		_queue_editor_refresh()

@export var editor_preview_lives: int = GameConstants.STARTING_LIVES:
	set(value):
		editor_preview_lives = value
		_queue_editor_refresh()

@export var show_editor_guide: bool = true:
	set(value):
		show_editor_guide = value
		queue_redraw()

var _icons_row: HBoxContainer
var _current_lives: int = -1
var _display_lives_override: int = -1
var _bonus_life_tween: Tween


func _enter_tree() -> void:
	_icons_row = get_node_or_null("IconsRow") as HBoxContainer
	_sync_editor_presentation()


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_editor_presentation()
		return

	add_to_group("lives_display")
	_apply_runtime_mouse_filters()
	if _icons_row != null:
		_icons_row.add_theme_constant_override("separation", icon_spacing)
	if not GameManager.run_changed.is_connected(_on_run_changed):
		GameManager.run_changed.connect(_on_run_changed)
	_on_run_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


func _sync_editor_presentation() -> void:
	if not Engine.is_editor_hint():
		return

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _icons_row != null:
		_icons_row.visible = true
		_icons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icons_row.add_theme_constant_override("separation", icon_spacing)

	var preview_count := clampi(editor_preview_lives, 0, max_lives_shown)
	_current_lives = -1
	set_lives(preview_count)
	queue_redraw()


func _apply_runtime_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icons_row != null:
		_icons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _queue_editor_refresh() -> void:
	if Engine.is_editor_hint():
		call_deferred("_sync_editor_presentation")


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_editor_guide:
		return

	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.92, 0.28, 0.32, 0.14), true)
	draw_rect(rect, Color(0.92, 0.28, 0.32, 0.9), false, 2.0)


func _on_run_changed() -> void:
	if Engine.is_editor_hint():
		return
	if _display_lives_override >= 0:
		return
	if GameManager.run == null:
		set_lives(0)
		return
	set_lives(GameManager.run.lives)


func set_lives(count: int) -> void:
	var clamped := clampi(count, 0, max_lives_shown)
	if clamped == _current_lives and _display_lives_override < 0:
		return
	_current_lives = clamped
	_refresh_icons(clamped)


func play_bonus_life_gain(from_lives: int, to_lives: int, on_complete: Callable = Callable()) -> void:
	if _bonus_life_tween != null and _bonus_life_tween.is_valid():
		_bonus_life_tween.kill()

	_display_lives_override = clampi(from_lives, 0, max_lives_shown)
	_current_lives = -1
	set_lives(_display_lives_override)

	var icons := _life_icon_nodes()
	var bonus_index := GameConstants.STARTING_LIVES
	if bonus_index >= icons.size():
		_finish_bonus_life_gain(to_lives, on_complete)
		return

	var bonus_icon := icons[bonus_index]
	bonus_icon.visible = true
	bonus_icon.texture = icon_texture
	bonus_icon.custom_minimum_size = icon_size
	bonus_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
	bonus_icon.scale = Vector2(0.35, 0.35)
	_update_layout_width(_slots_to_show(to_lives))

	_bonus_life_tween = create_tween()
	_bonus_life_tween.set_parallel(true)
	_bonus_life_tween.tween_property(bonus_icon, "modulate:a", 1.0, 0.22)
	_bonus_life_tween.tween_property(bonus_icon, "scale", Vector2.ONE, 0.28).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_bonus_life_tween.set_parallel(false)
	_bonus_life_tween.tween_interval(0.08)
	_bonus_life_tween.tween_callback(func() -> void:
		_finish_bonus_life_gain(to_lives, on_complete)
	)


func _finish_bonus_life_gain(to_lives: int, on_complete: Callable) -> void:
	_display_lives_override = -1
	_current_lives = -1
	set_lives(to_lives)
	if on_complete.is_valid():
		on_complete.call()


func _life_icon_nodes() -> Array[TextureRect]:
	var icons: Array[TextureRect] = []
	if _icons_row == null:
		return icons
	for child in _icons_row.get_children():
		if child is TextureRect:
			icons.append(child)
	return icons


func _slots_to_show(remaining_lives: int) -> int:
	var slots := maxi(GameConstants.STARTING_LIVES, mini(remaining_lives, max_lives_shown))
	if _bonus_life_slot_unlocked():
		slots = maxi(slots, GameConstants.STARTING_LIVES + 1)
	return slots


func _bonus_life_slot_unlocked() -> bool:
	if Engine.is_editor_hint() or GameManager.run == null:
		return false
	return GameManager.run.bonus_life_slot_unlocked


func _update_layout_width(slots_shown: int) -> void:
	var width := (
		float(slots_shown) * icon_size.x
		+ float(maxi(0, slots_shown - 1)) * float(icon_spacing)
	)
	custom_minimum_size.x = width
	size.x = width


func _refresh_icons(remaining_lives: int) -> void:
	if icon_texture == null or empty_icon_texture == null:
		return

	var slots_shown := _slots_to_show(remaining_lives)
	_update_layout_width(slots_shown)

	var icons := _life_icon_nodes()
	for i in icons.size():
		var icon := icons[i]
		var slot_visible := i < slots_shown
		icon.visible = slot_visible
		if not slot_visible:
			icon.scale = Vector2.ONE
			icon.modulate = Color.WHITE
			continue
		icon.texture = icon_texture if i < remaining_lives else empty_icon_texture
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.scale = Vector2.ONE
		icon.modulate = Color.WHITE
