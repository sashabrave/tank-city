extends RefCounted
static var DATA:Dictionary=Balance.CONFIG.weapon_data()

static func stats(id: String) -> Dictionary:return DATA.get(id,DATA.pistol)
