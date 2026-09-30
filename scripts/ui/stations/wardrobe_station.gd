extends RefCounted
## «Шкаф»: uniforms for the soldier (weapon skins come later). Built from Skins.UNIFORMS.
func title()->String:return "Шкаф"
func subtitle()->String:return "Форма бойца. Новые комплекты выпадают в бою."
func tabs()->Array:return [["uniform","Форма","fighter"],["weapons","Оружие","damage"]]
func items(tab:String)->Array:
	var result=[]
	if tab=="weapons":
		result.append({"id":"soon","title":"Скины оружия","icon":"damage","caption":"Скоро","state":"locked"});return result
	for id in Skins.UNIFORMS:
		var owned=Skins.owned(id)
		result.append({"id":id,"title":Skins.UNIFORMS[id].name,"icon":"fighter","texture":Skins.swatch(id),"caption":"Надета" if Game.skin==id else "Есть" if owned else "Закрыта","state":"active" if Game.skin==id else "owned" if owned else "locked"})
	return result
func detail(tab:String,id:String)->Dictionary:
	if tab=="weapons":return {"title":"Скины оружия","icon":"damage","text":"Появятся в следующих версиях.","actions":[]}
	var data=Skins.UNIFORMS[id];var owned=Skins.owned(id)
	return {"title":data.name,"icon":"fighter","texture":Skins.swatch(id),"text":Skins.SOURCE_TEXT[data.source],"actions":[{"id":"wear","text":"Надета" if Game.skin==id else "Надеть","enabled":owned and Game.skin!=id,"primary":true}]}
func act(tab:String,id:String,action:String)->String:
	if tab=="uniform" and action=="wear" and Skins.owned(id):
		Game.skin=id;Game.save_progress();return "Форма надета"
	return ""
