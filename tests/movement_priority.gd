extends SceneTree
func _initialize():call_deferred("run")
func press(game,action:String,echo:bool=false):
	Input.action_press(action)
	var event=InputEventAction.new();event.action=action;event.pressed=true
	if echo:
		var key=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true;key.echo=true;game._input(key)
	else:game._input(event)
func run():
	var game=root.get_node("Game");game.save_enabled=false;game.reset_input()
	press(game,"north");assert(game.direction()==Vector2i.UP)
	press(game,"east");assert(game.direction()==Vector2i.RIGHT)
	press(game,"north",true);assert(game.direction()==Vector2i.RIGHT,"key repeat must not steal priority")
	press(game,"south");assert(game.direction()==Vector2i.DOWN)
	Input.action_release("south");assert(game.direction()==Vector2i.RIGHT)
	Input.action_release("east");assert(game.direction()==Vector2i.UP)
	press(game,"west");assert(game.direction()==Vector2i.LEFT)
	Input.action_release("west");Input.action_release("north");assert(game.direction()==Vector2i.ZERO)
	game.reset_input()
	print("PASS movement: last press wins, repeats ignored, held-key fallback, release")
	quit()
