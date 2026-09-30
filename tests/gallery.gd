extends Node
var failures=0
func check(ok,message):
	if not ok:failures+=1;push_error(message)
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false
	var before=[Game.credits,Game.cores,Game.weapon_unlocks.duplicate(),Game.selected_weapon,Game.ability_unlocks.duplicate()]
	var gallery=load("res://scenes/test_gallery.tscn").instantiate();add_child(gallery)
	gallery.set_physics_process(false);gallery.player.set_physics_process(false)
	check(gallery.exhibits.size()>=80,"complete object catalog")
	var target=gallery.exhibits[0].actor;var original=target.position
	target.take_damage(9999)
	check(target.dead and not target.visible and gallery.respawns.size()==1,"death schedules respawn")
	gallery._physics_process(1.99);check(target.dead,"still dead before two seconds")
	gallery._physics_process(.02);check(not target.dead and target.visible and target.hp==target.max_hp and target.position==original,"restored at own stand after two seconds")
	var hp=gallery.player.hp;gallery.player.take_damage(9999);check(gallery.player.hp==hp,"invulnerable testing hero")
	gallery.focus_exhibit(0);var p=gallery.player;gallery.weapon="pistol";p.apply_weapon()
	var bullet=gallery.spawn_bullet(p,target.position,Vector2i.UP,1,true);bullet.set_physics_process(false);bullet.position=target.position
	var target_hp=target.hp;gallery.bullet_hit(bullet);check(target.hp<target_hp,"real player bullet damages enemy")
	var starts={}
	for actor in gallery.actors:starts[actor]=actor.position
	gallery._physics_process(8)
	check(gallery.attack_count>0,"stationary attacks run")
	for actor in starts:check(actor.position==starts[actor],"exhibit remains stationary")
	for i in range(gallery.exhibits.size()):gallery.focus_exhibit(i)
	check(before==[Game.credits,Game.cores,Game.weapon_unlocks,Game.selected_weapon,Game.ability_unlocks],"profile remains unchanged")
	print("GALLERY: ",gallery.exhibits.size()," exhibits, ",gallery.sections.size()," sections, ",failures," failures")
	gallery.queue_free();await get_tree().create_timer(.25).timeout;get_tree().quit(1 if failures else 0)
