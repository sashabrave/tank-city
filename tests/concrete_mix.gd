extends Node3D
func _ready():call_deferred("run")
func run():
	Game.save_enabled=false;Game.sound_enabled=false;Settings.persistence_enabled=false;Game.new_recipes.clear();Settings.values.fullscreen=false;Settings.apply()
	var seen={}
	for seed_value in range(1000):
		var style=preload("res://scripts/concrete_style.gd").pick(seed_value,Vector2i(3,5))
		assert(style==preload("res://scripts/concrete_style.gd").pick(seed_value,Vector2i(3,5)))
		seen[preload("res://scripts/concrete_style.gd").asset(style)]=true
	assert(seen.size()==27)
	Visuals.setup_world(self,12,Vector3(0,.3,0));set_meta("environment_floor",Color("92958e"))
	var families=["concrete_smooth","concrete_0","concrete_1"]
	for row in range(3):
		for shape in range(-1,8):
			var name=families[row]+("" if shape<0 else "_half_%d" % shape)
			var obj=Visuals.model(name,self,Vector3((shape-3)*1.15,0,(row-1)*1.35))
			var mesh=obj.find_children("*","MeshInstance3D",true,false)[0]
			var sections=[]
			for i in range(16):sections.append(1.0)
			var wall={"hp":-1,"sections":sections}
			if shape>=0:preload("res://scripts/section_wall.gd").set_half(wall,shape)
			var triangles=mesh.mesh.get_faces()
			for i in range(16):
				var pos=Vector3(-.375+(i%4)*.25,2,-.375+int(i/4)*.25);var hit=false
				for t in range(0,triangles.size(),3):
					if Geometry3D.segment_intersects_triangle(pos,pos-Vector3.UP*3,triangles[t],triangles[t+1],triangles[t+2])!=null:hit=true;break
				assert(hit==(sections[i]>0),"Visual/collision mismatch: %s section %d" % [name,i])
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(.6).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/concrete-mix.png")
	print("PASS all 27 style/shape combinations, deterministic selection, mesh matches all 16 collision sections")
	get_tree().quit()
