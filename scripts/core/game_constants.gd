class_name GameConstants

const BREW_VIEWPORT_SIZE := Vector2i(1024, 576)
const BREW_WINDOW_SIZE := Vector2i(2048, 1152)
const STARTING_LIVES := 3
const MAX_LIVES := 4
const LIFE_LOSS_GOLD_GRANT := 10
const DEFAULT_EXPLOSION_LIMIT := 8
const SHOP_SLOT_COUNT := 4
const SHOP_RARITY_WEIGHTS := [5, 4, 3, 2, 1]
const REROLL_COST := 2
const SHOP_MULLIGAN_COST := 5
const BREW_MULLIGAN_COST := 10
const BOSS_AURA_INTERVAL := 5
const MIN_BOSS_THRESHOLD := 1
const BOSS_AURA_WARNING := "You must complete the potion this round."
const PRACTICE_BREW_AURA_ID := "practice brew"
const IN_RHYTHM_AURA_ID := "in_rhythm"
const BUBBLING_BREW_AURA_ID := "bubbling_brew"
const BUBBLING_BREW_INTERVAL := 11
const THRESHOLD_START := 5
const THRESHOLD_STEP_BASE := 3
const EASY_THRESHOLD_STEP := 2
const THRESHOLD_LEVEL_GROWTH_MULTIPLIER := 1.03
const SAVE_FILE_NAME := "alchemy_roguelite_run.json"
const HIGH_SCORE_KEY := "alchemy_roguelite_highscores"


static func is_boss_level(level: int) -> bool:
	return level > 0 and level % BOSS_AURA_INTERVAL == 0


static func clamp_threshold_for_level(level: int, threshold: int) -> int:
	if is_boss_level(level):
		return maxi(MIN_BOSS_THRESHOLD, threshold)
	return threshold


static func boss_number(level: int) -> int:
	if not is_boss_level(level):
		return 0
	return level / BOSS_AURA_INTERVAL


static func boss_boom_berry_reward_ids(level: int) -> Array[String]:
	var boss := boss_number(level)
	if boss <= 0:
		return []
	if boss == 1:
		return ["boom_berry_1"]
	if boss == 2:
		return ["boom_berry_2"]
	var rewards: Array[String] = []
	if boss % 2 == 1:
		rewards.append("boom_berry_1")
	var tier_two_count := boss / 2 if boss % 2 == 0 else (boss - 1) / 2
	for _i in tier_two_count:
		rewards.append("boom_berry_2")
	return rewards