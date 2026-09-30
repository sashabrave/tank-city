extends Node
func _ready():
	Game.save_enabled=false
	var old=load("res://tests/fixtures/wave_director_before_editor.gd")
	var report=[]
	for room in range(6):
		var before=0.0;var after=0.0;var count_old=0;var count_new=0;var people=0;var machines=0
		for seed_value in range(1000):
			for wave in range(3):
				for entry in old.build(seed_value,room,wave):
					before+=old.rank_cost(entry.kind,entry.rank);count_old+=1
				for entry in WaveDirector.build(seed_value,room,wave):
					after+=WaveDirector.rank_cost(entry.kind,entry.rank);count_new+=1
					if entry.kind in WaveDirector.PEOPLE:people+=1
					else:machines+=1
		var surprise=Balance.CONFIG.campaign.drone_surprise_chance*2*3000
		report.append({"room":room+1,"old_count":count_old/3000.0,"new_count":count_new/3000.0,"old_budget":before/3000,"new_budget":after/3000,"with_surprises_ratio":(after+surprise)/before,"machine_share":machines/float(people+machines)})
	print(JSON.stringify(report,"\t"));get_tree().quit()
