class_name TrinketTooltip
extends PanelContainer

const VIEWPORT_MARGIN := 8.0
const GAP_BELOW_ICON := 6.0

@onready var _title_label: Label = $MarginContainer/Column/Title
@onready var _description_label: RichTextLabel = $MarginContainer/Column/Description


func bind(trinket: TrinketData) -> void:
	if trinket == null:
		_title_label.text = ""
		_description_label.text = ""
		return
	_title_label.text = trinket.display_name
	_description_label.text = trinket.description


func show_below_icon(icon_rect: Rect2) -> void:
	visible = true
	await get_tree().process_frame
	var viewport_size := get_viewport_rect().size
	var x := icon_rect.position.x + icon_rect.size.x * 0.5 - size.x * 0.5
	var y := icon_rect.end.y + GAP_BELOW_ICON
	x = clampf(x, VIEWPORT_MARGIN, viewport_size.x - size.x - VIEWPORT_MARGIN)
	y = clampf(y, VIEWPORT_MARGIN, viewport_size.y - size.y - VIEWPORT_MARGIN)
	global_position = Vector2(x, y)


func hide_tooltip() -> void:
	visible = false