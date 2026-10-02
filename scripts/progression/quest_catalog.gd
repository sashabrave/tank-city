extends RefCounted
## Quests for world 1 and endless. STORY and INSTITUTE are sequential chains; BRIEFINGS unlock when the
## "requires" counter reaches "threshold". Rewards: alloy and documents ("docs"); "xp" is kept for old saves.
## Senders shown in the tablet feed: Штаб усов (story), Институт (hub), Оперштаб (briefings and orders).
const STORY=[
{"id":"first_alloy","text":"Первый трофей","event":"extracted","goal":30,"alloy":30,"docs":0,"xp":25,"hint":"Подбери 30 сплава и вернись в хаб. Добровольный выход сохраняет добычу."},
{"id":"bench","text":"Плацдарм","event":"world_depth_1","goal":1,"alloy":40,"docs":0,"xp":35,"hint":"Зачисти первое поле Пограничья: три волны и командира."},
{"id":"health","text":"Подготовка бойца","event":"health_level","goal":1,"alloy":45,"docs":0,"xp":40,"hint":"В принтере открой «Общие улучшения» и купи здоровье."},
{"id":"rooms3","text":"Разведка двора","event":"world_depth_1","goal":3,"alloy":70,"docs":0,"xp":65,"hint":"Доберись до третьего поля и зачисти его. Сложные точки ★★ дальше по пути."},
{"id":"first_challenge","text":"Особое задание","event":"challenge_any","goal":1,"alloy":60,"docs":1,"xp":50,"hint":"На карте есть особые точки: тайник, удержание, выживание. Пройди любую."},
{"id":"first_trade","text":"Сделка на марше","event":"merchant_buy","goal":1,"alloy":50,"docs":0,"xp":40,"hint":"Собери жетоны с врагов и купи что-нибудь у торговца в сервисном ряду."},
{"id":"rooms5","text":"Подступы к генералу","event":"world_depth_1","goal":5,"alloy":100,"docs":0,"xp":85,"hint":"Пройди пять полей первого мира. Подготовь оружие и штаб к генералу."},
{"id":"general1","text":"Двор наш!","event":"world_clear_1","goal":1,"alloy":160,"docs":2,"xp":130,"hint":"Уничтожь генерала в конце мира 1. Откроется бесконечный режим."},
{"id":"endless_entry","text":"Удержать рубеж","event":"enter_endless","goal":1,"alloy":90,"docs":0,"xp":70,"hint":"В хабе нажми «В бой» и выбери бесконечный режим."},
{"id":"endless_cycle2","text":"Второй сектор","event":"endless_cycle","goal":2,"alloy":150,"docs":2,"xp":110,"hint":"В бесконечном режиме пройди семь комнат и начни второй сектор."},
{"id":"another_class","text":"Новая тактика","event":"boss_classes","goal":2,"alloy":300,"docs":2,"xp":250,"hint":"Выбери другой класс в Казарме и снова победи генерала мира 1."},
{"id":"endless_cycle5","text":"Несокрушимый рубеж","event":"endless_cycle","goal":5,"alloy":500,"docs":3,"xp":400,"hint":"Дойди до пятого сектора бесконечного режима. Нужна сильная сборка карт."}]
const INSTITUTE=[
{"id":"institute_arsenal","text":"Арсенал","event":"build_weapons","goal":1,"alloy":50,"docs":0,"xp":40,"hint":"Донеси чертёж Арсенала и построй его через «Строительство» в хабе."},
{"id":"shield","text":"Защита на марше","event":"use_shield","goal":1,"alloy":80,"docs":0,"xp":65,"hint":"Выбери щит и возьми его в вылазку."},
{"id":"supply","text":"Полевой запас","event":"camp_level","goal":1,"alloy":65,"docs":0,"xp":60,"hint":"В «Казарме» → Снабжение открой и улучши аптечки передышки."},
{"id":"hq_bench","text":"Штаб","event":"build_headquarters","goal":1,"alloy":100,"docs":0,"xp":90,"hint":"Донеси чертёж Штаба из сундука командира и построй его."},
{"id":"hq_equip","text":"Комплект поддержки","event":"equip_hq","goal":1,"alloy":80,"docs":0,"xp":70,"hint":"В Штабе → Технологии выбери модуль или активную технологию."},
{"id":"hq_support","text":"Связь со штабом","event":"use_hq","goal":3,"alloy":110,"docs":0,"xp":100,"hint":"Используй активный гаджет штаба три раза."},
{"id":"weapon_tune","text":"Доводка оружия","event":"weapon_level","goal":1,"alloy":100,"docs":0,"xp":100,"hint":"В Арсенале купи первый уровень открытого оружия."},
{"id":"shell_second","text":"Второй класс","event":"shells","goal":2,"alloy":90,"docs":1,"xp":80,"hint":"Открой второй класс бойца. Все классы доступны в мире 1."},
{"id":"drone","text":"Воздушный помощник","event":"recipe_ally_drone","goal":1,"alloy":130,"docs":1,"xp":110,"hint":"Найди чертёж дрона-помощника во второй половине пути и доставь в хаб."},
{"id":"comrade","text":"Совместная операция","event":"upgrade_comrade","goal":1,"alloy":170,"docs":1,"xp":140,"hint":"Возьми товарища и улучши его у инструктора."},
{"id":"airstrike","text":"Поддержка авиации","event":"recipe_airstrike","goal":1,"alloy":220,"docs":2,"xp":180,"hint":"Чертёж авиаудара выпадает на сложных точках ближе к генералу и с него самого."},
{"id":"shell_all","text":"Все классы","event":"shells","goal":6,"alloy":400,"docs":3,"xp":300,"hint":"Открой все классы бойца."}]
const BRIEFINGS=[
{"id":"garage_build","text":"Стоянка","event":"build_garage","goal":1,"alloy":70,"docs":0,"xp":65,"requires":"world_depth_1","threshold":2,"hint":"Найди чертёж Стоянки и построй её — в «Строительстве» или в Штабе → Постройки."},
{"id":"garage_buggy","text":"Личный багги","event":"own_buggy","goal":1,"alloy":100,"docs":0,"xp":90,"requires":"build_garage","threshold":1,"hint":"Добудь чертёж багги и купи машину на стоянке."},
{"id":"garage_equipment","text":"Оборудование машины","event":"vehicle_equipment","goal":1,"alloy":100,"docs":0,"xp":90,"requires":"own_buggy","threshold":1,"hint":"Донеси чертёж оборудования и купи улучшение на стоянке."},
{"id":"garage_apc","text":"Бронегруппа","event":"own_apc","goal":1,"alloy":200,"docs":1,"xp":170,"requires":"own_buggy","threshold":1,"hint":"Чертёж БТР выпадает во второй половине пути мира 1. Купи машину на стоянке."},
{"id":"garage_tank","text":"Тяжёлый прорыв","event":"own_tank","goal":1,"alloy":350,"docs":2,"xp":280,"requires":"own_apc","threshold":1,"hint":"Чертёж танка — самый редкий: сложные точки у генерала и сам генерал."},
{"id":"hq_upgrade","text":"Технология штаба","event":"upgrade_hq","goal":1,"alloy":120,"docs":0,"xp":110,"requires":"build_headquarters","threshold":1,"hint":"В Штабе купи постоянный уровень технологии."},
{"id":"visit_mechanic","text":"Полевой механик","event":"visit_vehicle","goal":1,"alloy":50,"docs":0,"xp":40,"requires":"world_depth_1","threshold":1,"hint":"На карте мира 1 механик стоит обычной точкой второго–третьего этапа. Загляни к нему."},
{"id":"visit_workshop","text":"Мастерская штаба","event":"visit_headquarters","goal":1,"alloy":60,"docs":0,"xp":50,"requires":"world_depth_1","threshold":3,"hint":"Мастерская штаба ждёт на четвёртом–пятом этапе маршрута."},
{"id":"challenge_cache","text":"Вскрыть тайник","event":"challenge_cache","goal":1,"alloy":80,"docs":1,"xp":60,"requires":"world_depth_1","threshold":1,"hint":"Открой тайник и отбейся от засады ветеранов."},
{"id":"challenge_hold","text":"Точка удержана","event":"challenge_hold","goal":1,"alloy":80,"docs":1,"xp":60,"requires":"world_depth_1","threshold":1,"hint":"Пройди удержание: стой в зоне, пока шкала не заполнится."},
{"id":"challenge_survive","text":"Под огнём","event":"challenge_survive","goal":1,"alloy":80,"docs":1,"xp":60,"requires":"world_depth_1","threshold":1,"hint":"Пройди выживание без патронов под артобстрелом."},
{"id":"challenge_hard","text":"Две звезды","event":"challenge_hard","goal":3,"alloy":200,"docs":2,"xp":150,"requires":"challenge_any","threshold":2,"hint":"Пройди три испытания со звёздами ★★."},
{"id":"barrels","text":"Бочковой салют","event":"barrel_kills","goal":5,"alloy":70,"docs":0,"xp":50,"requires":"world_depth_1","threshold":1,"hint":"Уничтожь пятерых врагов взрывом бочек."},
{"id":"tokens","text":"Коллекционер жетонов","event":"tokens","goal":25,"alloy":80,"docs":0,"xp":60,"requires":"merchant_buy","threshold":1,"hint":"Собери 25 жетонов. Их чаще носят техника и ветераны, командир — всегда."},
{"id":"slot_machine","text":"Азартный рядовой","event":"slot_play","goal":5,"alloy":60,"docs":0,"xp":40,"requires":"merchant_buy","threshold":1,"hint":"Сыграй пять раз на игровом автомате торговца."},
{"id":"tactics","text":"Тактик","event":"behavior_cards","goal":3,"alloy":90,"docs":1,"xp":70,"requires":"world_depth_1","threshold":2,"hint":"Возьми три карты «Тактика» за всё время."},
{"id":"stack","text":"Специалист","event":"card_stack","goal":5,"alloy":150,"docs":1,"xp":110,"requires":"world_depth_1","threshold":3,"hint":"В одном забеге возьми пять одинаковых карт улучшения."}]
const TELEGRAMS=[
{"id":"buggy_patrol","vehicle":"buggy","text":"Враги на багги","event":"kills_buggy","goal":12,"alloy":80,"xp":50},
{"id":"apc_patrol","vehicle":"apc","text":"Враги на БТР","event":"kills_apc","goal":18,"alloy":130,"xp":80},
{"id":"tank_patrol","vehicle":"tank","text":"Враги на танке","event":"kills_tank","goal":24,"alloy":200,"xp":120},
{"id":"infantry","text":"Пехота","event":"infantry","goal":20,"alloy":55,"xp":35},
{"id":"armor","text":"Техника","event":"armor","goal":6,"alloy":65,"xp":40},
{"id":"waves","text":"Волны","event":"waves","goal":6,"alloy":60,"xp":40},
{"id":"drones","text":"Дроны","event":"drones","goal":10,"alloy":60,"xp":40},
{"id":"barrel_order","text":"Бочки","event":"barrel_kills","goal":4,"alloy":70,"xp":45},
{"id":"token_order","text":"Жетоны","event":"tokens","goal":10,"alloy":60,"xp":40}]
const SENDERS={"story":{"name":"Штаб усов","icon":"quests","color":"c9793f"},"institute":{"name":"Институт","icon":"guide","color":"3f9a8f"},"operations":{"name":"Оперштаб","icon":"notifications","color":"4f86c6"}}
static func sender(q:Dictionary)->String:
	if str(q.get("id","")).begins_with("order_") or q in BRIEFINGS:return "operations"
	if q in INSTITUTE:return "institute"
	return "story"
static func hint(id:String)->String:
	for q in STORY+INSTITUTE+BRIEFINGS:
		if q.id==id:return q.get("hint","")
	return "Выполни приказ за указанные вылазки. Награда в командном центре."
static func counter_name(event:String)->String:
	if event.begins_with("world_depth"):return "Полей пройдено"
	if event.begins_with("challenge_"):return "Испытаний пройдено"
	return {"armor":"Техники уничтожено","infantry":"Пехоты уничтожено","drones":"Дронов уничтожено","waves":"Волн зачищено","kills_buggy":"Убийств на багги","kills_apc":"Убийств на БТР","kills_tank":"Убийств на танке","extracted":"Сплава доставлено","endless_fields":"Полей рубежа","endless_cycle":"Сектор","merchant_buy":"Покупок","tokens":"Жетонов собрано","slot_play":"Игр на автомате","barrel_kills":"Врагов взорвано","behavior_cards":"Карт «Тактика»","card_stack":"Одинаковых карт","shells":"Классов","visit_vehicle":"Визитов","visit_headquarters":"Визитов"}.get(event,"Прогресс")
