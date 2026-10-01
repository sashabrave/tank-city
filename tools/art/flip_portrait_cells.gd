extends SceneTree
## Mirrors every cell of the 3×2 class portrait/miniature atlases left↔right in place.
## Usage: Godot --headless --path . -s tools/art/flip_portrait_cells.gd -- <png>...
func _init():
	for path in OS.get_cmdline_user_args():
		var image=Image.load_from_file(path)
		var cell=Vector2i(image.get_width()/3,image.get_height()/2)
		for y in 2:
			for x in 3:
				var rect=Rect2i(Vector2i(x,y)*cell,cell)
				var part=image.get_region(rect);part.flip_x();image.blit_rect(part,Rect2i(Vector2i.ZERO,cell),rect.position)
		image.save_png(path);print("flipped ",path)
	quit()
