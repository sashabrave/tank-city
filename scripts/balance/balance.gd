class_name Balance
extends RefCounted
static var CONFIG:GameBalance=preload("res://assets/balance/game_balance.tres")
## Reward strength for a rarity tier (common/rare/epic); tiers above the table use the last value.
static func tier_power(tier:int)->float:
	var table=CONFIG.combat.reward_tier_power
	return table[clampi(tier,0,table.size()-1)]
static func speed_cap()->float:return CONFIG.combat.player_speed_cap
static func speed_multiplier_cap()->float:return CONFIG.combat.speed_multiplier_cap
