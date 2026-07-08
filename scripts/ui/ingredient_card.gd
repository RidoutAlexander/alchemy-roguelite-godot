class_name IngredientCard
extends Button

## Optional overrides — leave empty to use whatever you placed in the scene.
@export_group("Art Slots")
@export var card_background_texture: Texture2D
@export var name_plate_texture: Texture2D
@export var description_plate_texture: Texture2D
@export var cost_plate_texture: Texture2D
@export var art_frame_texture: Texture2D
@export var points_icon_texture: Texture2D
@export var explosive_icon_texture: Texture2D
@export var cost_icon_texture: Texture2D

signal offer_pressed(slot_index: int)
signal puzzle_drag_began(card: IngredientCard)
signal choice_pressed(card: IngredientCard)
signal picker_card_pressed(card: IngredientCard)
signal hand_drag_began(card: IngredientCard)
signal hand_hover_changed(hovered: bool)

const CARD_TINT_SHADER := preload("res://shaders/card_rarity_tint.gdshader")

const HOVER_SCALE := 1.08
const PICKER_SELECT_SCALE := 1.04
const HAND_HOVER_SCALE := 1.12
const HAND_SELECTED_SCALE := 1.22
const HAND_HOVER_RISE := 28.0
const SCALE_SPEED := 12.0
const HAND_CARD_SCALE := 0.34
const HAND_CARD_BASE_SIZE := Vector2(300.0, 420.0)
const HAND_EFFECT_ICON_GAP := 4.0
const HAND_EFFECT_ICON_CLEARANCE := 6.0
const HAND_SCROLL_TOP_LOCAL_Y := -81.0
const _DEFAULT_STAT_COLOR := Color(0.05, 0.05, 0.05, 1)
const _SCORE_UP_COLOR := Color(0.12, 0.62, 0.18, 1)
const _SCORE_DOWN_COLOR := Color(0.82, 0.18, 0.14, 1)
const _EXPLOSIVE_UP_COLOR := Color(0.82, 0.18, 0.14, 1)
const _EXPLOSIVE_DOWN_COLOR := Color(0.12, 0.62, 0.18, 1)
const _MODIFIED_STAT_OUTLINE_COLOR := Color(0, 0, 0, 1)
const _MODIFIED_STAT_OUTLINE_SIZE := 4

@onready var _visual_root: Control = $VisualRoot
@onready var _card_background: TextureRect = $VisualRoot/CardBackground
@onready var _name_label: Label = $VisualRoot/NamePlate/NameLabel
@onready var _art_frame_bg: TextureRect = $VisualRoot/ArtArea/ArtFrameBackground
@onready var _art_texture: TextureRect = $VisualRoot/ArtArea/IngredientArt
@onready var _art_placeholder: Label = $VisualRoot/ArtArea/ArtPlaceholder
@onready var _points_icon: TextureRect = $VisualRoot/StatsRow/PointsStat/Icon
@onready var _points_value: Label = $VisualRoot/StatsRow/PointsStat/ValueLabel
@onready var _explosive_icon: TextureRect = $VisualRoot/StatsRow/ExplosiveStat/IconBackground
@onready var _explosive_value: Label = $VisualRoot/StatsRow/ExplosiveStat/ValueLabel
@onready var _description_label: Label = $VisualRoot/DescriptionPanel/DescriptionLabel
@onready var _cost_plate_bg: TextureRect = $VisualRoot/CostRow/CostPlateBackground
@onready var _cost_icon: TextureRect = $VisualRoot/CostRow/Icon
@onready var _cost_label: Label = $VisualRoot/CostRow/CostLabel
@onready var _hand_effect_icons: HandSlotEffectIcons = $HandSlotEffectIcons

var _name_plate_bg: TextureRect
var _description_plate_bg: TextureRect
var _name_plate_fallback: ColorRect
var _description_plate_fallback: ColorRect
var _explosive_icon_fallback: ColorRect
var _scene_art_locked: bool = false

var _slot_index: int = -1
var _ingredient: IngredientData
var _price: int = 0
var _has_offer: bool = false
var _rarity_tint := Color.WHITE
var _hover_enabled: bool = false
var _is_hovered: bool = false
var _puzzle_drag_enabled: bool = false
var _hand_mode: bool = false
var _hand_drag_enabled: bool = false
var _hand_slot_index: int = -1
var _hand_hover_offset: float = 0.0
var _hand_selected: bool = false
var _choice_mode: bool = false
var _picker_mode: bool = false
var _picker_selected: bool = false
var _puzzle_press_position: Vector2 = Vector2.INF
var _hand_press_position: Vector2 = Vector2.INF
var _is_animating: bool = false
var _base_point_value: int = 0
var _base_explosive_value: int = 0


func _ready() -> void:
	_cache_optional_nodes()
	_scene_art_locked = _art_texture != null and _art_texture.texture != null

	flat = true
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	_make_button_transparent()
	_apply_optional_art_overrides()
	_sync_ingredient_art_visibility()
	_set_empty_state()
	resized.connect(_on_resized)
	gui_input.connect(_on_gui_input)
	_ignore_visual_mouse_input(_visual_root)
	_update_hover_pivot()
	set_process(false)


func _cache_optional_nodes() -> void:
	_name_plate_bg = get_node_or_null("VisualRoot/NamePlate/PlateBackground") as TextureRect
	_description_plate_bg = get_node_or_null("VisualRoot/DescriptionPanel/PlateBackground") as TextureRect
	_name_plate_fallback = get_node_or_null("VisualRoot/NamePlate/NamePlateFallback") as ColorRect
	_description_plate_fallback = get_node_or_null("VisualRoot/DescriptionPanel/DescriptionFallback") as ColorRect
	_explosive_icon_fallback = get_node_or_null("VisualRoot/StatsRow/ExplosiveStat/IconFallback") as ColorRect


func get_ingredient() -> IngredientData:
	return _ingredient


func bind_hand_card(
	ingredient: IngredientData,
	slot_index: int,
	drag_enabled: bool,
	display_point_value: int = -1,
	display_explosive_value: int = -1,
	effect_entries: Array = []
) -> void:
	_reset_mode_flags()
	_hand_mode = true
	_hand_slot_index = slot_index
	_hand_drag_enabled = drag_enabled
	_base_point_value = ingredient.point_value if ingredient != null else 0
	_base_explosive_value = ingredient.explosive_value if ingredient != null else 0
	bind_preview(ingredient)
	var point_display := (
		display_point_value if display_point_value >= 0 else _base_point_value
	)
	var explosive_display := (
		display_explosive_value if display_point_value >= 0 else _base_explosive_value
	)
	if is_node_ready():
		update_hand_stat_display(point_display, explosive_display)
	else:
		call_deferred("update_hand_stat_display", point_display, explosive_display)
	_apply_hand_layout()
	_bind_hand_effect_entries(effect_entries)
	_sync_hand_input()


func update_hand_stat_display(point_value: int, explosive_value: int) -> void:
	if not is_node_ready() or not _hand_mode:
		return
	_points_value.text = "%d" % point_value
	_apply_hand_stat_color(_points_value, point_value, _base_point_value, true)
	if explosive_value > 0 or _base_explosive_value > 0:
		_explosive_value.text = "%d" % explosive_value
		_apply_hand_stat_color(_explosive_value, explosive_value, _base_explosive_value, false)
		$VisualRoot/StatsRow/ExplosiveStat.visible = true
	else:
		_explosive_value.text = ""
		$VisualRoot/StatsRow/ExplosiveStat.visible = false


func _reset_hand_stat_label_colors() -> void:
	_clear_hand_stat_label_style(_points_value)
	_clear_hand_stat_label_style(_explosive_value)


func _clear_hand_stat_label_style(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", _DEFAULT_STAT_COLOR)
	label.remove_theme_color_override("font_outline_color")
	label.add_theme_constant_override("outline_size", 0)


func _apply_hand_stat_color(
	label: Label,
	display_value: int,
	base_value: int,
	higher_is_good: bool
) -> void:
	if label == null:
		return
	if display_value > base_value:
		label.add_theme_color_override(
			"font_color",
			_SCORE_UP_COLOR if higher_is_good else _EXPLOSIVE_UP_COLOR
		)
	elif display_value < base_value:
		label.add_theme_color_override(
			"font_color",
			_SCORE_DOWN_COLOR if higher_is_good else _EXPLOSIVE_DOWN_COLOR
		)
	else:
		label.add_theme_color_override("font_color", _DEFAULT_STAT_COLOR)

	if display_value != base_value:
		label.add_theme_color_override(
			"font_outline_color",
			_MODIFIED_STAT_OUTLINE_COLOR
		)
		label.add_theme_constant_override("outline_size", _MODIFIED_STAT_OUTLINE_SIZE)
	else:
		label.remove_theme_color_override("font_outline_color")
		label.add_theme_constant_override("outline_size", 0)


func clear_hand_card() -> void:
	set_hand_selected(false)
	_base_point_value = 0
	_base_explosive_value = 0
	_reset_hand_stat_label_colors()
	_clear_hand_effect_entries()
	_reset_mode_flags()
	_set_empty_state()


func set_hand_selected(selected: bool) -> void:
	if not _hand_mode:
		_hand_selected = false
		return
	_hand_selected = selected
	if selected:
		_snap_hand_highlight(true)
	elif not _is_hovered:
		_snap_hand_highlight(false)


func is_hand_selected() -> bool:
	return _hand_selected


func get_hand_hit_rect() -> Rect2:
	var hit_rect := get_global_rect()
	if _visual_root != null:
		hit_rect = hit_rect.merge(_visual_root.get_global_rect())
	return hit_rect


func update_hand_hover(hovered: bool, delta: float) -> void:
	if not _hand_mode or _visual_root == null:
		return
	var target_scale := _hand_target_scale(hovered)
	var target_rise := -HAND_HOVER_RISE if hovered or _hand_selected else 0.0
	var next_scale := lerpf(_visual_root.scale.x, target_scale, SCALE_SPEED * delta)
	_visual_root.scale = Vector2.ONE * next_scale
	_hand_hover_offset = lerpf(_hand_hover_offset, target_rise, SCALE_SPEED * delta)
	_visual_root.position.y = _hand_hover_offset
	_update_hand_effect_icon_position()


func _hand_target_scale(hovered: bool) -> float:
	if _hand_selected:
		return HAND_SELECTED_SCALE
	if hovered:
		return HAND_HOVER_SCALE
	return 1.0


func _apply_hand_layout() -> void:
	scale = Vector2.ONE
	custom_minimum_size = HAND_CARD_BASE_SIZE
	size = HAND_CARD_BASE_SIZE
	pivot_offset = Vector2.ZERO
	if _visual_root != null:
		_visual_root.scale = Vector2.ONE
		_visual_root.position = Vector2.ZERO
		_visual_root.pivot_offset = Vector2(HAND_CARD_BASE_SIZE.x * 0.5, HAND_CARD_BASE_SIZE.y)
		_hand_hover_offset = 0.0
	scale = Vector2.ONE * HAND_CARD_SCALE
	pivot_offset = Vector2(HAND_CARD_BASE_SIZE.x * 0.5, HAND_CARD_BASE_SIZE.y) * HAND_CARD_SCALE
	_apply_hand_effect_layout()


func _snap_hand_highlight(active: bool) -> void:
	if _visual_root == null:
		return
	if active:
		_visual_root.scale = Vector2.ONE * _hand_target_scale(false)
		_hand_hover_offset = -HAND_HOVER_RISE
	else:
		_visual_root.scale = Vector2.ONE
		_hand_hover_offset = 0.0
	_visual_root.position.y = _hand_hover_offset
	_update_hand_effect_icon_position()


func _bind_hand_effect_entries(entries: Array) -> void:
	if _hand_effect_icons == null:
		return
	if entries.is_empty():
		_hand_effect_icons.clear_icons()
		return
	_hand_effect_icons.bind_entries(entries, _lookup_effect_ingredient)
	_update_hand_effect_icon_position()


func _clear_hand_effect_entries() -> void:
	if _hand_effect_icons != null:
		_hand_effect_icons.clear_icons()


func _apply_hand_effect_layout() -> void:
	if _hand_effect_icons == null:
		return
	_hand_effect_icons.z_index = 1
	_hand_effect_icons.scale = Vector2.ONE / HAND_CARD_SCALE
	var strip_size := _hand_effect_icons.custom_minimum_size
	if _hand_effect_icons.size != Vector2.ZERO:
		strip_size = _hand_effect_icons.size
	var scaled_strip_width := strip_size.x * _hand_effect_icons.scale.x
	_hand_effect_icons.position.x = (HAND_CARD_BASE_SIZE.x - scaled_strip_width) * 0.5
	_update_hand_effect_icon_position()


func _hand_effect_scroll_top_y() -> float:
	if _visual_root == null:
		return 0.0
	var visual_scale := _visual_root.scale.y
	var pivot_y := HAND_CARD_BASE_SIZE.y
	return (
		_hand_hover_offset
		+ (HAND_SCROLL_TOP_LOCAL_Y - pivot_y) * visual_scale
		+ pivot_y
	)


func _hand_effect_icon_y() -> float:
	var scroll_top := _hand_effect_scroll_top_y()
	var offset_below_scroll := (
		HAND_EFFECT_ICON_GAP
		+ HandSlotEffectIcons.ICON_SIZE
		+ HAND_EFFECT_ICON_CLEARANCE
	) / HAND_CARD_SCALE
	return scroll_top - offset_below_scroll


func _update_hand_effect_icon_position() -> void:
	if _hand_effect_icons == null or not _hand_mode or not _hand_effect_icons.visible:
		return
	_hand_effect_icons.position.y = _hand_effect_icon_y()


func _lookup_effect_ingredient(ingredient_id: String) -> IngredientData:
	if GameManager.run == null:
		return null
	return GameManager.run.find_ingredient(ingredient_id)


func _sync_hand_input() -> void:
	if not _hand_mode:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	disabled = true
	focus_mode = Control.FOCUS_NONE
	_hover_enabled = false
	_hand_press_position = Vector2.INF
	set_process(true)


func _reset_mode_flags() -> void:
	_puzzle_drag_enabled = false
	_hand_mode = false
	_hand_drag_enabled = false
	_hand_slot_index = -1
	_hand_hover_offset = 0.0
	_hand_selected = false
	_choice_mode = false
	_picker_mode = false
	_picker_selected = false


func bind_puzzle_card(ingredient: IngredientData) -> void:
	set_puzzle_drag_enabled(true)
	bind_preview(ingredient)
	apply_puzzle_layout()


func bind_choice_card(ingredient: IngredientData) -> void:
	_choice_mode = true
	_hover_enabled = true
	_has_offer = false
	bind_preview(ingredient)


func bind_picker_card(ingredient: IngredientData) -> void:
	_picker_mode = true
	_choice_mode = false
	_picker_selected = false
	_puzzle_drag_enabled = false
	_hover_enabled = false
	_is_hovered = false
	bind_preview(ingredient)
	apply_puzzle_layout()
	_apply_picker_visual_pivot()
	sync_picker_input()


func is_picker_mode() -> bool:
	return _picker_mode


func set_picker_selected(selected: bool) -> void:
	if not _picker_mode:
		return
	_picker_selected = selected
	if selected:
		_is_hovered = false
		set_process(false)
		if _visual_root != null:
			_visual_root.scale = Vector2.ONE * PICKER_SELECT_SCALE
	else:
		_is_hovered = false
		set_process(false)
		_reset_visual_scale()


func set_picker_drag_enabled(_enabled: bool) -> void:
	_puzzle_drag_enabled = false
	sync_picker_input()


func sync_picker_input() -> void:
	if not _picker_mode:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	disabled = false
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	_reset_visual_scale()


func apply_puzzle_layout() -> void:
	EyeballPuzzleLayout.configure_card(self)


func set_puzzle_drag_enabled(enabled: bool) -> void:
	_puzzle_drag_enabled = enabled
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	_reset_visual_scale()
	if is_node_ready():
		_sync_puzzle_input()


func _sync_puzzle_input() -> void:
	if _puzzle_drag_enabled:
		_has_offer = _ingredient != null
		mouse_filter = Control.MOUSE_FILTER_STOP
		disabled = false
		focus_mode = Control.FOCUS_NONE
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		_puzzle_press_position = Vector2.INF
		apply_puzzle_layout()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		disabled = true
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_puzzle_press_position = Vector2.INF


func bind_preview(ingredient: IngredientData) -> void:
	if is_queued_for_deletion():
		return
	if not is_node_ready():
		call_deferred("bind_preview", ingredient)
		return
	if ingredient == null:
		_set_empty_state()
		return

	if not _hand_mode:
		_slot_index = -1
	_is_animating = false
	_ingredient = ingredient
	_price = 0
	_has_offer = true
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	_reset_visual_scale()
	visible = true
	_visual_root.visible = true
	_ensure_card_background_visible()
	_name_label.text = ingredient.display_name
	_description_label.text = IngredientEffects.card_display_description(ingredient)
	if _hand_mode:
		_reset_hand_stat_label_colors()
	else:
		_points_value.text = "%d" % ingredient.point_value
		if ingredient.explosive_value > 0:
			_explosive_value.text = "%d" % ingredient.explosive_value
			$VisualRoot/StatsRow/ExplosiveStat.visible = true
		else:
			_explosive_value.text = ""
			$VisualRoot/StatsRow/ExplosiveStat.visible = false
	_set_cost_row_visible(false)
	_apply_rarity_tint(ingredient.rarity)
	_apply_ingredient_art(ingredient)
	if _hand_mode:
		_sync_hand_input()
	elif _puzzle_drag_enabled:
		_sync_puzzle_input()
	elif _picker_mode:
		sync_picker_input()
	elif _choice_mode:
		mouse_filter = Control.MOUSE_FILTER_STOP
		disabled = false
		_hover_enabled = true
		set_process(true)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		disabled = true


func set_offer_hover_enabled(enabled: bool) -> void:
	if not _has_offer or _is_animating:
		return
	_hover_enabled = enabled
	if not enabled:
		_is_hovered = false
		_reset_visual_scale()
	set_process(enabled)


func bind_offer(
	ingredient: IngredientData,
	price: int,
	slot_index: int,
	display_rarity: int = -1
) -> void:
	if not is_node_ready():
		call_deferred("bind_offer", ingredient, price, slot_index, display_rarity)
		return
	if _is_animating:
		return

	_slot_index = slot_index
	_is_animating = false
	_hover_enabled = false
	_is_hovered = false
	_reset_visual_scale()
	if ingredient == null:
		_set_empty_state()
		return
	_ingredient = ingredient
	_price = price
	_has_offer = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_visual_root.visible = true
	disabled = false
	_hover_enabled = true
	set_process(true)
	_ensure_card_background_visible()
	_name_label.text = ingredient.display_name
	_description_label.text = IngredientEffects.card_display_description(ingredient)
	_cost_label.text = "%d" % price
	_points_value.text = "%d" % ingredient.point_value
	if ingredient.explosive_value > 0:
		_explosive_value.text = "%d" % ingredient.explosive_value
		$VisualRoot/StatsRow/ExplosiveStat.visible = true
	else:
		_explosive_value.text = ""
		$VisualRoot/StatsRow/ExplosiveStat.visible = false
	_set_cost_row_visible(true)
	var rarity := ingredient.rarity
	if display_rarity >= 0:
		rarity = display_rarity as IngredientData.Rarity
	_apply_rarity_tint(rarity)
	_apply_ingredient_art(ingredient)


func _set_cost_row_visible(visible_row: bool) -> void:
	var cost_row := $VisualRoot.get_node_or_null("CostRow")
	if cost_row != null:
		cost_row.visible = visible_row


func get_art_global_center() -> Vector2:
	if not is_node_ready():
		return get_global_rect().get_center()
	if _art_texture != null and _art_texture.visible:
		var art_rect := _art_texture.get_global_rect()
		if art_rect.size.x >= 2.0 and art_rect.size.y >= 2.0:
			return art_rect.get_center()
	return get_global_rect().get_center()


func capture_fly_data() -> Dictionary:
	if not is_node_ready() or not _has_offer:
		return {}

	var texture: Texture2D = null
	if _art_texture != null and _art_texture.texture != null:
		texture = _art_texture.texture
	elif _ingredient != null:
		var art_path := "res://assets/cards/ingredients/%s.png" % _ingredient.get_art_filename()
		if ResourceLoader.exists(art_path):
			texture = load(art_path)
	if texture == null:
		return {}

	var art_rect := _art_texture.get_global_rect() if _art_texture != null else get_global_rect()
	if art_rect.size.x < 2.0 or art_rect.size.y < 2.0:
		var center := get_global_rect().get_center()
		art_rect = Rect2(center - Vector2(48.0, 48.0), Vector2(96.0, 96.0))

	return {
		"texture": texture,
		"size": art_rect.size,
		"start_center": art_rect.get_center(),
	}


func hide_for_purchase() -> void:
	_is_animating = true
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	disabled = true
	_reset_visual_scale()
	_visual_root.visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear_purchased_slot() -> void:
	_is_animating = false
	_set_empty_state()


func _apply_optional_art_overrides() -> void:
	_set_texture_if_empty(_card_background, card_background_texture)
	_set_texture_if_empty(_name_plate_bg, name_plate_texture, _name_plate_fallback)
	_set_texture_if_empty(_description_plate_bg, description_plate_texture, _description_plate_fallback)
	_set_texture_if_empty(_cost_plate_bg, cost_plate_texture)
	_set_texture_if_empty(_art_frame_bg, art_frame_texture)
	_set_texture_if_empty(_points_icon, points_icon_texture)
	_set_texture_if_empty(_explosive_icon, explosive_icon_texture, _explosive_icon_fallback)
	_set_texture_if_empty(_cost_icon, cost_icon_texture)


func _apply_rarity_tint(rarity: int) -> void:
	if _card_background == null:
		return
	_rarity_tint = RarityPalette.card_tint(rarity)
	_card_background.modulate = Color.WHITE
	var tint_material := _card_background.material as ShaderMaterial
	if tint_material == null:
		tint_material = ShaderMaterial.new()
		tint_material.shader = CARD_TINT_SHADER
		_card_background.material = tint_material
	tint_material.set_shader_parameter("tint_color", _rarity_tint)
	tint_material.set_shader_parameter("tint_strength", RarityPalette.card_tint_strength(rarity))


func _ensure_card_background_visible() -> void:
	if _card_background == null:
		return
	_card_background.visible = true


func _reset_visual_scale() -> void:
	if _visual_root != null:
		_visual_root.scale = Vector2.ONE


func _ignore_visual_mouse_input(node: Node) -> void:
	if node is Control and node != self:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_visual_mouse_input(child)


func _apply_ingredient_art(ingredient: IngredientData) -> void:
	if _art_texture == null:
		return

	if _scene_art_locked:
		_sync_ingredient_art_visibility()
		return

	var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
	if ResourceLoader.exists(art_path):
		_art_texture.texture = load(art_path)
		_art_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art_texture.visible = true
		if _art_placeholder != null:
			_art_placeholder.visible = false
	else:
		_art_texture.texture = null
		_art_texture.visible = false
		if _art_placeholder != null:
			_art_placeholder.visible = true
			_art_placeholder.text = ingredient.display_name


func _sync_ingredient_art_visibility() -> void:
	if _art_texture == null:
		return
	var has_art := _art_texture.texture != null
	_art_texture.visible = has_art
	if _art_placeholder != null:
		_art_placeholder.visible = not has_art


func _set_empty_state() -> void:
	if not is_node_ready():
		return
	_reset_mode_flags()
	_has_offer = false
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	disabled = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_visual_scale()
	_visual_root.visible = false


func _make_button_transparent() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)


func _set_texture_if_empty(
	target: TextureRect,
	texture: Texture2D,
	fallback: CanvasItem = null
) -> void:
	if target == null or texture == null or target.texture != null:
		return
	target.texture = texture
	target.visible = true
	if fallback != null:
		fallback.visible = false


func _on_resized() -> void:
	_update_hover_pivot()


func _update_hover_pivot() -> void:
	if _visual_root != null:
		_visual_root.pivot_offset = _visual_root.size * 0.5


func _is_cursor_over_card() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _apply_picker_visual_pivot() -> void:
	if _visual_root == null:
		return
	_visual_root.pivot_offset = Vector2(_visual_root.size.x * 0.5, _visual_root.size.y)


func _process(delta: float) -> void:
	if _hand_mode:
		var hovered := _is_cursor_over_card()
		if hovered != _is_hovered:
			_is_hovered = hovered
			hand_hover_changed.emit(hovered)
		return
	if _picker_mode:
		return
	if _picker_selected or not _hover_enabled or _is_animating or _visual_root == null:
		return
	_is_hovered = _is_cursor_over_card()
	var target_scale := HOVER_SCALE if _is_hovered else 1.0
	var next_scale := lerpf(_visual_root.scale.x, target_scale, SCALE_SPEED * delta)
	_visual_root.scale = Vector2.ONE * next_scale


func _on_gui_input(event: InputEvent) -> void:
	if _hand_drag_enabled and _ingredient != null:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_hand_press_position = event.global_position
			else:
				_hand_press_position = Vector2.INF
		elif event is InputEventMouseMotion and _hand_press_position != Vector2.INF:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				return
			if event.global_position.distance_to(_hand_press_position) < 8.0:
				return
			_hand_press_position = Vector2.INF
			hand_drag_began.emit(self)
			accept_event()
		return
	if not _puzzle_drag_enabled or _ingredient == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_puzzle_press_position = event.global_position
		else:
			_puzzle_press_position = Vector2.INF
	elif event is InputEventMouseMotion and _puzzle_press_position != Vector2.INF:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		if event.global_position.distance_to(_puzzle_press_position) < 8.0:
			return
		_puzzle_press_position = Vector2.INF
		puzzle_drag_began.emit(self)
		accept_event()


func _on_pressed() -> void:
	if _hand_mode:
		return
	if _picker_mode and not _is_animating:
		picker_card_pressed.emit(self)
		return
	if _choice_mode and not _is_animating:
		choice_pressed.emit(self)
		return
	if _puzzle_drag_enabled:
		return
	if _has_offer and not _is_animating:
		_is_hovered = false
		_reset_visual_scale()
		offer_pressed.emit(_slot_index)
