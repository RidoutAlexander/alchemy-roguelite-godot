class_name ShopPanel
extends Control

const _IngredientFlyUtil := preload("res://scripts/ui/ingredient_fly_util.gd")
const SHOP_BAG_FLY_TARGET_GROUP := "shop_bag_fly_target"
const BOOM_BERRY_REWARD_FLY_SIZE := Vector2(112.0, 112.0)
const BOOM_BERRY_REWARD_NOTE_FADE_DELAY := 2.4
const BOOM_BERRY_REWARD_NOTE_FADE_DURATION := 0.55
const BAG_COUNT_LABEL_INSET := Vector2(0.0, 6.0)

@export var bag_fly_target_path: NodePath = NodePath("BagTarget/BagIcon")

@onready var _gold_counter: GoldDisplay = $GoldCounter
@onready var _reroll_button: ShopRerollButton = $RerollButton
@onready var _reroll_cost: GoldCostBadge = $RerollCost
@onready var _buy_mulligan_button: ShopRerollButton = $BuyMulliganButton
@onready var _buy_mulligan_cost: ShopButtonCostOverlay = $BuyMulliganCost
@onready var _shop_gold_popups: ShopGoldSpentPopups = $ShopGoldPopups
@onready var leave_shop_button: WoodenButton = $LeaveShopButton
@onready var _fly_layer: CanvasLayer = $FlyLayer
@onready var _shop_select_pop_player: AudioStreamPlayer = $ShopSelectPopPlayer
@onready var _boom_berry_reward_note: Label = $BagTarget/BoomBerryRewardNote
@onready var _bag_target: Control = $BagTarget
@onready var _bag_button: TextureButton = $BagTarget/BagButton
@onready var _bag_count_label: Label = $BagTarget/BagCountLabel
@onready var _bag_contents: BagContentsOverlay = $BagContentsOverlay
@onready var _level_aura_banner: LevelAuraBanner = $LevelAuraBanner

var offer_cards: Array[IngredientCard] = []
var _purchase_animations_pending: int = 0
var _boss_reward_animation_active: bool = false
var _boom_berry_reward_note_tween: Tween


func _ready() -> void:
	_gather_offer_cards()
	if leave_shop_button != null and not leave_shop_button.pressed.is_connected(GameManager.leave_shop):
		leave_shop_button.pressed.connect(GameManager.leave_shop)
	else:
		push_error("ShopPanel: LeaveShopButton not found")
	if _reroll_button != null and not _reroll_button.pressed.is_connected(_on_reroll_pressed):
		_reroll_button.pressed.connect(_on_reroll_pressed)
	if _buy_mulligan_button != null and not _buy_mulligan_button.pressed.is_connected(
		_on_buy_mulligan_pressed
	):
		_buy_mulligan_button.pressed.connect(_on_buy_mulligan_pressed)
	if _bag_button != null and not _bag_button.pressed.is_connected(_on_bag_button_pressed):
		_bag_button.pressed.connect(_on_bag_button_pressed)
	if _bag_contents != null and not _bag_contents.overlay_closed.is_connected(_on_bag_contents_closed):
		_bag_contents.overlay_closed.connect(_on_bag_contents_closed)

	for card in offer_cards:
		card.offer_pressed.connect(_on_offer_pressed)
	GameManager.run_changed.connect(refresh)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("refresh")


func _gather_offer_cards() -> void:
	offer_cards.clear()
	for i in GameConstants.SHOP_SLOT_COUNT:
		var card := $OfferCards.get_node_or_null("ShopOffer%dCard" % i) as IngredientCard
		if card != null:
			offer_cards.append(card)


func _on_visibility_changed() -> void:
	if visible:
		refresh()
		call_deferred("_align_bag_count_label")
		call_deferred("_try_play_boss_boom_berry_reward")
	else:
		_hide_bag_contents()
		_reset_shop_interaction_locks()


func _on_bag_button_pressed() -> void:
	if GameManager.run == null or _bag_contents == null:
		return
	_bag_contents.toggle(GameManager.run.bag)
	_set_offer_hover_enabled(not _bag_contents.is_open())
	_play_shop_select_pop()


func _on_bag_contents_closed() -> void:
	_set_offer_hover_enabled(true)
	call_deferred("_align_bag_count_label")


func _hide_bag_contents() -> void:
	if _bag_contents != null:
		_bag_contents.hide_overlay()
	_set_offer_hover_enabled(true)


func _set_offer_hover_enabled(enabled: bool) -> void:
	for card in offer_cards:
		if card == null:
			continue
		card.set_offer_hover_enabled(enabled)
		if enabled:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.disabled = false
		else:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.disabled = true


func _play_shop_select_pop() -> void:
	if _shop_select_pop_player == null:
		return
	_shop_select_pop_player.stop()
	_shop_select_pop_player.play()


func _on_reroll_pressed() -> void:
	if _purchase_animations_pending > 0:
		return
	var run := GameManager.run
	if run == null:
		return
	var spent: int = run.get_shop_reroll_cost()
	if GameManager.try_reroll_shop():
		_play_shop_select_pop()
		_show_gold_spent(spent)
		refresh()
	elif _gold_counter != null:
		_gold_counter.shake()


func _on_buy_mulligan_pressed() -> void:
	if _purchase_animations_pending > 0:
		return
	var run := GameManager.run
	if run == null:
		return
	var spent: int = run.get_shop_mulligan_cost()
	if GameManager.try_buy_shop_mulligan():
		_play_shop_select_pop()
		_show_gold_spent(spent)
		refresh()
	elif _gold_counter != null:
		_gold_counter.shake()
		if _buy_mulligan_button != null:
			_buy_mulligan_button.shake()


func _on_offer_pressed(slot_index: int) -> void:
	if _purchase_animations_pending > 0:
		return
	var run := GameManager.run
	if run == null:
		return
	if slot_index < 0 or slot_index >= run.current_shop_offers.size():
		return
	var offer: ShopService.ShopOffer = run.current_shop_offers[slot_index]
	if offer == null:
		return
	if run.gold < offer.price:
		if _gold_counter != null:
			_gold_counter.shake()
		return
	if slot_index < 0 or slot_index >= offer_cards.size():
		return

	var card := offer_cards[slot_index]
	var fly_data := card.capture_fly_data()

	var spent: int = offer.price
	_purchase_animations_pending += 1
	if not GameManager.try_purchase_offer(slot_index):
		_purchase_animations_pending = maxi(0, _purchase_animations_pending - 1)
		return

	_play_shop_select_pop()
	_show_gold_spent(spent)
	refresh_stats_only()
	card.hide_for_purchase()
	_start_purchase_fly(slot_index, fly_data)


func _resolve_bag_fly_target() -> CanvasItem:
	for node in get_tree().get_nodes_in_group(SHOP_BAG_FLY_TARGET_GROUP):
		if node is CanvasItem and _is_descendant_of_shop(node):
			return node as CanvasItem

	if bag_fly_target_path != NodePath():
		var configured := get_node_or_null(bag_fly_target_path) as CanvasItem
		if configured != null:
			return configured

	var bag_icon := find_child("BagIcon", true, false) as CanvasItem
	if bag_icon != null:
		return bag_icon

	var bag_target := find_child("BagTarget", true, false) as CanvasItem
	if bag_target != null:
		return bag_target

	return null


func _is_descendant_of_shop(node: Node) -> bool:
	return node == self or is_ancestor_of(node)


func _resolve_bag_fly_target_center() -> Vector2:
	var bag_target := _resolve_bag_fly_target()
	return _IngredientFlyUtil.global_control_center(bag_target)


func _start_purchase_fly(slot_index: int, fly_data: Dictionary) -> void:
	if fly_data.is_empty():
		_on_purchase_fly_finished(slot_index)
		return

	var texture: Texture2D = fly_data["texture"]
	var start_center: Vector2 = fly_data["start_center"]
	var display_size: Vector2 = fly_data["size"]
	_spawn_purchase_flyer(texture, start_center, display_size, slot_index)


func _spawn_purchase_flyer(
	texture: Texture2D,
	start_center: Vector2,
	display_size: Vector2,
	slot_index: int
) -> void:
	var target_center := _resolve_bag_fly_target_center()
	_IngredientFlyUtil.play(
		_fly_layer,
		texture,
		start_center,
		target_center,
		display_size,
		func() -> void:
			_on_purchase_fly_finished(slot_index)
	)


func _on_purchase_fly_finished(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < offer_cards.size():
		offer_cards[slot_index].clear_purchased_slot()
	_purchase_animations_pending = maxi(0, _purchase_animations_pending - 1)
	if _purchase_animations_pending == 0:
		refresh()
	_refresh_bag_contents_if_open()


func _try_play_boss_boom_berry_reward() -> void:
	if not visible or GameManager.run == null:
		return
	if _boss_reward_animation_active:
		return
	if GameManager.run.pending_boss_boom_berry_reward_ids.is_empty():
		_hide_boom_berry_reward_note()
		return

	while absf(offset_left) > 0.5 or _purchase_animations_pending > 0:
		await get_tree().create_timer(0.05).timeout
		if not is_inside_tree() or not visible:
			return
		if (
			GameManager.run == null
			or GameManager.run.pending_boss_boom_berry_reward_ids.is_empty()
		):
			return

	var rewards := GameManager.run.take_pending_boss_boom_berry_reward()
	if rewards.is_empty():
		_hide_boom_berry_reward_note()
		return
	await _play_boss_boom_berry_rewards(rewards)


func _play_boss_boom_berry_rewards(rewards: Array[IngredientData]) -> void:
	_boss_reward_animation_active = true
	_show_boom_berry_reward_note(rewards)

	var target_center := _resolve_bag_fly_target_center()
	var start_center := target_center + Vector2(-140.0, -260.0)
	for berry_index in rewards.size():
		var ingredient: IngredientData = rewards[berry_index]
		var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
		if not ResourceLoader.exists(art_path):
			continue
		var texture: Texture2D = load(art_path)
		if texture == null:
			continue
		var flew := await _await_boss_boom_berry_fly(
			texture,
			start_center + Vector2(float(berry_index) * -18.0, float(berry_index) * -12.0),
			target_center
		)
		if not flew:
			break
		_refresh_bag_contents_if_open()

	_finish_boss_boom_berry_rewards()


func _await_boss_boom_berry_fly(
	texture: Texture2D,
	start_center: Vector2,
	target_center: Vector2
) -> bool:
	if not is_inside_tree() or not visible:
		return false

	var fly_finished := false
	_spawn_boss_boom_berry_fly(
		texture,
		start_center,
		target_center,
		func() -> void:
			fly_finished = true
	)
	while not fly_finished:
		if not is_inside_tree() or not visible:
			return false
		await get_tree().process_frame
	return true


func _finish_boss_boom_berry_rewards() -> void:
	_boss_reward_animation_active = false
	_schedule_boom_berry_reward_note_fade()
	_restore_shop_offers()


func _restore_shop_offers() -> void:
	var bag_open := _bag_contents != null and _bag_contents.is_open()
	_set_offer_hover_enabled(not bag_open)
	refresh()


func _reset_shop_interaction_locks() -> void:
	_boss_reward_animation_active = false
	_purchase_animations_pending = 0


func _spawn_boss_boom_berry_fly(
	texture: Texture2D,
	start_center: Vector2,
	target_center: Vector2,
	on_complete: Callable = Callable()
) -> void:
	_IngredientFlyUtil.play(
		_fly_layer,
		texture,
		start_center,
		target_center,
		BOOM_BERRY_REWARD_FLY_SIZE,
		func() -> void:
			if on_complete.is_valid():
				on_complete.call(),
		func() -> void:
			_play_shop_select_pop()
			_bounce_bag_target()
	)


func _show_boom_berry_reward_note(rewards: Array[IngredientData]) -> void:
	if _boom_berry_reward_note == null:
		return
	if _boom_berry_reward_note_tween != null and _boom_berry_reward_note_tween.is_valid():
		_boom_berry_reward_note_tween.kill()
		_boom_berry_reward_note_tween = null
	_boom_berry_reward_note.text = _format_boom_berry_reward_note(rewards)
	_boom_berry_reward_note.modulate = Color.WHITE
	_boom_berry_reward_note.visible = true


func _format_boom_berry_reward_note(rewards: Array[IngredientData]) -> String:
	if rewards.is_empty():
		return ""
	var counts: Dictionary = {}
	for ingredient in rewards:
		if ingredient == null:
			continue
		var label := ingredient.display_name
		counts[label] = int(counts.get(label, 0)) + 1
	if counts.is_empty():
		return ""

	var parts: Array[String] = []
	for label_key in counts.keys():
		var label: String = str(label_key)
		var count: int = int(counts[label_key])
		if count == 1:
			parts.append("a %s" % label)
		else:
			var plural_label: String = label
			if plural_label.ends_with("Berry"):
				plural_label = plural_label.substr(0, plural_label.length() - 5) + "Berries"
			parts.append("%d %s" % [count, plural_label])

	if parts.size() == 1:
		var single := parts[0]
		if single.begins_with("a "):
			return "A %s has been added to your bag" % single.substr(2)
		return "%s have been added to your bag" % single
	if parts.size() == 2:
		return "%s and %s have been added to your bag" % [
			_format_reward_article(parts[0]),
			parts[1],
		]
	var joined := ", ".join(parts.slice(0, parts.size() - 1))
	return "%s, and %s have been added to your bag" % [joined, parts[-1]]


func _format_reward_article(part: String) -> String:
	if part.begins_with("a "):
		return "A %s" % part.substr(2)
	return part


func _hide_boom_berry_reward_note() -> void:
	if _boom_berry_reward_note == null:
		return
	if _boom_berry_reward_note_tween != null and _boom_berry_reward_note_tween.is_valid():
		_boom_berry_reward_note_tween.kill()
		_boom_berry_reward_note_tween = null
	_boom_berry_reward_note.visible = false
	_boom_berry_reward_note.modulate = Color.WHITE


func _schedule_boom_berry_reward_note_fade() -> void:
	if _boom_berry_reward_note == null or not _boom_berry_reward_note.visible:
		return
	if _boom_berry_reward_note_tween != null and _boom_berry_reward_note_tween.is_valid():
		_boom_berry_reward_note_tween.kill()
	_boom_berry_reward_note_tween = create_tween()
	_boom_berry_reward_note_tween.tween_interval(BOOM_BERRY_REWARD_NOTE_FADE_DELAY)
	_boom_berry_reward_note_tween.tween_property(
		_boom_berry_reward_note,
		"modulate:a",
		0.0,
		BOOM_BERRY_REWARD_NOTE_FADE_DURATION
	)
	_boom_berry_reward_note_tween.finished.connect(
		func() -> void:
			_hide_boom_berry_reward_note()
	)


func _align_bag_count_label() -> void:
	if _bag_count_label == null or _bag_button == null or not visible:
		return
	var label_size := _bag_count_label.get_minimum_size()
	label_size.x = maxf(label_size.x, 28.0)
	label_size.y = maxf(label_size.y, 24.0)
	_bag_count_label.custom_minimum_size = label_size
	_bag_count_label.size = label_size
	var bag_rect := _bag_button.get_rect()
	_bag_count_label.position = Vector2(
		bag_rect.position.x + (bag_rect.size.x - label_size.x) * 0.5,
		bag_rect.end.y + BAG_COUNT_LABEL_INSET.y
	)


func _bounce_bag_target() -> void:
	if _bag_target == null:
		return
	var base_scale := _bag_target.scale
	var tween := create_tween()
	tween.tween_property(_bag_target, "scale", base_scale * Vector2(1.08, 0.94), 0.07)
	tween.tween_property(_bag_target, "scale", base_scale * Vector2(0.96, 1.05), 0.08)
	tween.tween_property(_bag_target, "scale", base_scale, 0.1).set_trans(Tween.TRANS_BOUNCE)


func _refresh_bag_contents_if_open() -> void:
	if _bag_contents != null:
		_bag_contents.refresh_if_open()


func refresh() -> void:
	refresh_stats_only()
	_refresh_bag_contents_if_open()
	if _purchase_animations_pending > 0:
		return
	if GameManager.run == null:
		return
	var run := GameManager.run
	for i in offer_cards.size():
		if i < run.current_shop_offers.size():
			var offer = run.current_shop_offers[i]
			if offer != null:
				var display_rarity := TrinketEffects.shop_rarity_for_ingredient(
					offer.ingredient,
					run.owned_trinket_ids
				)
				offer_cards[i].bind_offer(offer.ingredient, offer.price, i, int(display_rarity))
			else:
				offer_cards[i].bind_offer(null, 0, i)
		else:
			offer_cards[i].bind_offer(null, 0, i)


func refresh_stats_only() -> void:
	if GameManager.run == null:
		return
	var run := GameManager.run
	_refresh_upcoming_aura_preview(run)
	if _bag_count_label != null:
		_bag_count_label.text = str(run.bag.master_count())
		call_deferred("_align_bag_count_label")
	if _gold_counter != null:
		_gold_counter.set_amount(run.gold)
	if _reroll_button != null:
		var reroll_cost := run.get_shop_reroll_cost()
		if _reroll_cost != null:
			_reroll_cost.set_cost(reroll_cost)
		_reroll_button.disabled = reroll_cost > 0 and run.gold < reroll_cost
		_reroll_button.modulate = Color(0.55, 0.55, 0.55, 1.0) if _reroll_button.disabled else Color.WHITE
	_refresh_buy_mulligan_controls(run)


func _refresh_buy_mulligan_controls(run: RunManager) -> void:
	if _buy_mulligan_cost != null:
		_buy_mulligan_cost.set_cost(run.get_shop_mulligan_cost())
	if _buy_mulligan_button == null:
		return
	var mulligan_cost := run.get_shop_mulligan_cost()
	_buy_mulligan_button.disabled = run.gold < mulligan_cost
	_buy_mulligan_button.modulate = (
		Color(0.55, 0.55, 0.55, 1.0) if _buy_mulligan_button.disabled else Color.WHITE
	)


func _refresh_upcoming_aura_preview(run: RunManager) -> void:
	if _level_aura_banner == null:
		return
	var level := run.get_upcoming_brew_level()
	var aura := run.ensure_aura_locked_for_upcoming_brew()
	_level_aura_banner.bind_preview(level, aura)


func _show_gold_spent(amount: int) -> void:
	if _shop_gold_popups == null or _gold_counter == null:
		return
	_shop_gold_popups.show_spent(amount, _gold_counter)
