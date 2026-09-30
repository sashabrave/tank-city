@tool
class_name UpgradeDef
extends Resource
## One run upgrade card. Applying, card text, preview and offer rules all read this definition;
## nothing else in the code describes what the card does.
@export var id:String=""
@export var title:String=""
@export_enum("Герой","Оружие","Способность","Тактика") var category:String="Герой"
@export var icon:String=""
## Card family for build attraction: fire, survival, ammo, recon, logistics (RunUpgrades.FAMILIES).
@export_enum("fire","survival","ammo","recon","logistics") var family:String="fire"
## Lowest rarity this card can appear at: 0 common, 1 rare, 2 epic, 3 legendary.
@export_range(0,3,1) var min_tier:int=0
## Behaviour switch read by CombatMods (crit_stun, chain_fire…): taking the card adds its id to behavior_cards.
@export var flag:bool=false
## Free tags for pools, families and synergies (weapon, infantry, vehicle, device, behavior…).
@export var tags:PackedStringArray=PackedStringArray()
## Relative chance among eligible cards. 0 keeps the card out of random offers.
@export_range(0,100,1) var weight:int=10
## How many times one run may take the card. 0 means unlimited.
@export_range(0,20,1) var max_stacks:int=0
## Offer conditions: "abilities" — the hero has at least one ability slot.
@export var requires:PackedStringArray=PackedStringArray()
## Stat changes per unit of reward power. Keys: stat, op (add, add_round, scale, pow), value, cap.
## stat is a RunState field or "weapon_mods.@weapon.<key>"; cap is a number or a Balance.CONFIG.combat field name.
@export var modifiers:Array[Dictionary]=[]
## Measured before/after value shown on the card: hp, speed, rate, damage, intercept, range, healing, device_power, device_cooldown.
@export var preview:String=""
## Extra text under the preview; the only text for behaviour cards.
@export_multiline var detail:String=""
## Optional RunEffect script: event handlers and live modifiers (on_vehicle_exit, modify_shot_damage…).
@export var effect:Script
