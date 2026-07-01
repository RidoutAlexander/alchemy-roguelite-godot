@tool
class_name DrawnCardPreviewHost
extends Control

@export var show_editor_guide: bool = true:
	set(value):
		show_editor_guide = value
		queue_redraw()


func _enter_tree() -> void:
	_sync_editor_presentation()


func _ready() -> void:
	_sync_editor_presentation()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


func _sync_editor_presentation() -> void:
	if Engine.is_editor_hint():
		visible = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card := get_node_or_null("DrawnCardPreview") as CanvasItem
		if card != null:
			card.visible = true
			if card is Control:
				(card as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
	else:
		visible = false


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_editor_guide:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.95, 0.75, 0.2, 0.16), true)
	draw_rect(rect, Color(0.95, 0.75, 0.2, 0.9), false, 2.0)