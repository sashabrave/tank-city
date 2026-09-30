extends RefCounted
const STORY=[
{"id":"first_alloy","text":"Первый трофей","event":"extracted","goal":30,"alloy":30,"xp":25,"hint":"Подбери 30 сплава и вернись в хаб. Добровольный выход сохраняет добычу."},
{"id":"bench","text":"Плацдарм","event":"world_depth_1","goal":1,"alloy":40,"xp":35,"hint":"В первом мире зачисти поле, три волны и командира."},
{"id":"health","text":"Подготовка бойца","event":"health_level","goal":1,"alloy":45,"xp":40,"hint":"В принтере открой «Общие статы» и купи +2 HP."},
{"id":"rooms3","text":"Разведка границы","event":"world_depth_1","goal":3,"alloy":70,"xp":65,"hint":"Доберись до третьего поля Пограничья и зачисти его."},
{"id":"rooms5","text":"Подступы к генералу","event":"world_depth_1","goal":5,"alloy":100,"xp":85,"hint":"Пройди пять полей первого мира. Подготовь оружие и штаб к генералу."},
{"id":"general1","text":"Пограничье под контролем","event":"world_clear_1","goal":1,"alloy":160,"xp":130,"hint":"Уничтожь генерала в конце мира 1. Откроются мир 2 и бесконечный режим."},
{"id":"front_entry","text":"Линия фронта","event":"enter_world_2","goal":1,"alloy":90,"xp":70,"hint":"В хабе нажми «В бой», выбери второй мир и начни операцию."},
{"id":"rooms10","text":"Прорыв фронта","event":"world_depth_2","goal":4,"alloy":200,"xp":150,"hint":"Зачисти четвёртое поле мира 2. Ищи чертежи БТР и снайперской винтовки."},
{"id":"general2","text":"Фронт прорван","event":"world_clear_2","goal":1,"alloy":260,"xp":200,"hint":"Победи генерала девятого поля мира 2. Откроется Цитадель."},
{"id":"citadel_entry","text":"К стенам Цитадели","event":"enter_world_3","goal":1,"alloy":150,"xp":110,"hint":"Начни мир 3 через экран операций. Здесь открываются танк и РПГ."},
{"id":"citadel","text":"Последний рубеж","event":"world_clear_3","goal":1,"alloy":400,"xp":300,"hint":"Пройди Цитадель. В финале отключи четыре генератора и уничтожь гигабосса."},
{"id":"another_class","text":"Новая тактика","event":"boss_classes","goal":2,"alloy":500,"xp":400,"hint":"Выбери другой класс в принтере и снова победи гигабосса."}]
const INSTITUTE=[
{"id":"institute_character","text":"Прокачка базы","event":"build_character","goal":1,"alloy":50,"xp":40,"hint":"Чертёж открыт. Построй верстак через «Строительство» в хабе."},
{"id":"shield","text":"Защита на марше","event":"use_shield","goal":1,"alloy":80,"xp":65,"hint":"Выбери щит и возьми его в вылазку."},
{"id":"supply","text":"Полевой запас","event":"camp_level","goal":1,"alloy":65,"xp":60,"hint":"Улучши аптечки передышки в «Прокачке базы»."},
{"id":"hq_bench","text":"Верстак штаба","event":"build_headquarters","goal":1,"alloy":100,"xp":90,"hint":"Донеси чертёж верстака штаба из элитного сундука и построй его."},
{"id":"hq_equip","text":"Комплект поддержки","event":"equip_hq","goal":1,"alloy":80,"xp":70,"hint":"Выбери модуль или активный гаджет штаба на его верстаке."},
{"id":"hq_support","text":"Связь со штабом","event":"use_hq","goal":3,"alloy":110,"xp":100,"hint":"Используй активный гаджет штаба на Q три раза."},
{"id":"weapon_tune","text":"Доводка оружия","event":"weapon_level","goal":1,"alloy":100,"xp":100,"hint":"Купи первый уровень открытого оружия на оружейном верстаке."},
{"id":"bonus_bench","text":"Склад снабжения","event":"build_bonuses","goal":1,"alloy":100,"xp":80,"hint":"Донеси чертёж верстака бонусов, затем построй его."},
{"id":"drone","text":"Воздушный помощник","event":"recipe_ally_drone","goal":1,"alloy":130,"xp":110,"hint":"Во втором мире найди чертёж дрона и доставь в хаб."},
{"id":"comrade","text":"Совместная операция","event":"upgrade_comrade","goal":1,"alloy":170,"xp":140,"hint":"Возьми товарища и улучши его в точке способностей."},
{"id":"airstrike","text":"Поддержка авиации","event":"recipe_airstrike","goal":1,"alloy":220,"xp":180,"hint":"Найди чертёж авиаудара в Цитадели и доставь на базу."}]
const BRIEFINGS=[
{"id":"endless_briefing","text":"Приказ: удерживать рубеж","event":"world_clear_1","goal":1,"alloy":90,"xp":80,"requires":"world_depth_1","threshold":3,"hint":"После третьего поля получен приказ. Победи первого генерала: откроется бесконечный режим."},
{"id":"endless_patrol","text":"Проверка рубежа","event":"endless_fields","goal":3,"alloy":120,"xp":90,"requires":"world_clear_1","threshold":1,"hint":"Зачисти три поля в бесконечном режиме. Можно за несколько вылазок."},
{"id":"garage_build","text":"Стоянка","event":"build_garage","goal":1,"alloy":70,"xp":65,"requires":"world_depth_1","threshold":2,"hint":"Найди чертёж стоянки в мире 1 и построй её в хабе."},
{"id":"garage_buggy","text":"Личный багги","event":"own_buggy","goal":1,"alloy":100,"xp":90,"requires":"build_garage","threshold":1,"hint":"Добудь чертёж багги в мире 1, купи машину на стоянке."},
{"id":"garage_equipment","text":"Оборудование машины","event":"vehicle_equipment","goal":1,"alloy":100,"xp":90,"requires":"own_buggy","threshold":1,"hint":"Донеси чертёж оборудования и купи улучшение на стоянке."},
{"id":"garage_apc","text":"Бронегруппа","event":"own_apc","goal":1,"alloy":200,"xp":170,"requires":"world_clear_1","threshold":1,"hint":"Чертёж БТР в мире 2. Для покупки нужны багги и база 3."},
{"id":"garage_tank","text":"Тяжёлый прорыв","event":"own_tank","goal":1,"alloy":350,"xp":280,"requires":"world_clear_2","threshold":1,"hint":"Чертёж танка в мире 3. Для покупки нужны БТР и база 5."},
{"id":"hq_upgrade","text":"Технология штаба","event":"upgrade_hq","goal":1,"alloy":120,"xp":110,"requires":"build_headquarters","threshold":1,"hint":"Купи постоянный уровень технологии на верстаке штаба."}]
const TELEGRAMS=[
{"id":"buggy_patrol","vehicle":"buggy","text":"Враги на багги","event":"kills_buggy","goal":12,"alloy":80,"xp":50},
{"id":"apc_patrol","vehicle":"apc","text":"Враги на БТР","event":"kills_apc","goal":18,"alloy":130,"xp":80},
{"id":"tank_patrol","vehicle":"tank","text":"Враги на танке","event":"kills_tank","goal":24,"alloy":200,"xp":120},
{"id":"infantry","text":"Пехота","event":"infantry","goal":20,"alloy":55,"xp":35},
{"id":"armor","text":"Техника","event":"armor","goal":6,"alloy":65,"xp":40},
{"id":"waves","text":"Волны","event":"waves","goal":6,"alloy":60,"xp":40},
{"id":"drones","text":"Дроны","event":"drones","goal":10,"alloy":60,"xp":40}]
static func hint(id:String)->String:
	for q in STORY+INSTITUTE+BRIEFINGS:
		if q.id==id:return q.get("hint","")
	return "Выполни приказ за указанные вылазки. Награда в командном центре."
static func counter_name(event:String)->String:
	if event.begins_with("world_depth"):return "Полей пройдено"
	return {"armor":"Техники уничтожено","infantry":"Пехоты уничтожено","drones":"Дронов уничтожено","waves":"Волн зачищено","kills_buggy":"Убийств на багги","kills_apc":"Убийств на БТР","kills_tank":"Убийств на танке","extracted":"Сплава доставлено","endless_fields":"Полей рубежа"}.get(event,"Прогресс")
