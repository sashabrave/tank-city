extends RefCounted
## «Шкаф»: uniforms for the soldier, the player's cat model (PlayerModels); weapon skins come later.
func title()->String:return "Шкаф"
func subtitle()->String:return "Форма бойца. Новые комплекты выпадают в бою."
func tabs()->Array:return [["uniform","Форма","fighter"],["model","Модель игрока","fighter"],["weapons","Оружие","damage"]]
func items(tab:String)->Array:
	var result=[]
	if tab=="weapons":
		result.append({"id":"soon","title":"Скины оружия","icon":"damage","caption":"Скоро","state":"locked"});return result
	if tab=="model":
		for id in PlayerModels.MODELS:
			if not PlayerModels.valid(id):continue
			var worn=Game.player_model==id
			result.append({"id":id,"title":PlayerModels.MODELS[id].name,"icon":"fighter","caption":"Выбрана" if worn else "Есть","state":"active" if worn else "owned"})
		return result
	for id in Skins.UNIFORMS:
		var owned=Skins.owned(id)
		result.append({"id":id,"title":Skins.UNIFORMS[id].name,"icon":"fighter","texture":Skins.swatch(id),"caption":"Надета" if Game.skin==id else "Есть" if owned else "Закрыта","state":"active" if Game.skin==id else "owned" if owned else "locked"})
	return result
func detail(tab:String,id:String)->Dictionary:
	if tab=="weapons":return {"title":"Скины оружия","icon":"damage","text":"Появятся в следующих версиях.","actions":[]}
	if tab=="model":
		var model=PlayerModels.MODELS[id];var worn=Game.player_model==id
		return {"title":model.name,"icon":"fighter","text":model.text,"actions":[{"id":"use","text":"Выбрана" if worn else "Выбрать","enabled":not worn,"primary":true}]}
	var data=Skins.UNIFORMS[id];var owned=Skins.owned(id)
	return {"title":data.name,"icon":"fighter","texture":Skins.swatch(id),"text":Skins.SOURCE_TEXT[data.source],"actions":[{"id":"wear","text":"Надета" if Game.skin==id else "Надеть","enabled":owned and Game.skin!=id,"primary":true}]}
func act(tab:String,id:String,action:String)->String:
	if tab=="model" and action=="use" and PlayerModels.valid(id):
		Game.player_model=id;Game.save_progress();return "Модель выбрана"
	if tab=="uniform" and action=="wear" and Skins.owned(id):
		Game.skin=id;Game.save_progress();return "Форма надета"
	return ""
