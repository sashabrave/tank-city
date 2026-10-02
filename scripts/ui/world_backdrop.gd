extends Control
## Placeholder art for a world card until res://assets/ui/worlds/<id>.png exists: a soft sky, layered hills
## and a few silhouettes that hint at the world (yard fences, ridge pines, citadel towers, endless horizon).
var tint=Color("6d8a5a")
var kind=0
func _draw():
	var w=size.x;var h=size.y
	for i in range(12):
		var t=i/11.0
		draw_rect(Rect2(0,h*t*.62,w,h*.62/11.0+1),tint.lightened(.55-.3*t))
	draw_circle(Vector2(w*.74,h*.22),h*.07,Color(1,.95,.82,.85))
	for layer in range(3):
		var points=PackedVector2Array([Vector2(0,h)])
		var base=h*(.55+layer*.12);var amp=h*(.08-layer*.015)
		for x in range(0,int(w)+8,8):points.append(Vector2(x,base-amp*(.5+.5*sin(x*.03+layer*1.7+kind))))
		points.append(Vector2(w,h))
		draw_colored_polygon(points,tint.darkened(.15+layer*.18))
	var ink=tint.darkened(.62)
	match kind:
		0:
			for x in range(10,int(w),18):draw_rect(Rect2(x,h*.78,4,h*.08),ink)
			draw_rect(Rect2(0,h*.8,w,3),ink)
		1:
			for k in range(6):
				var x=w*(.08+k*.17);var y=h*(.62+fmod(k*.37,.12))
				draw_colored_polygon(PackedVector2Array([Vector2(x,y-h*.16),Vector2(x-h*.05,y),Vector2(x+h*.05,y)]),ink)
		2:
			for k in range(3):
				var x=w*(.2+k*.3);var top=h*(.42+k%2*.08)
				draw_rect(Rect2(x-12,top,24,h-top),ink)
				for b in range(3):draw_rect(Rect2(x-14+b*10,top-8,6,8),ink)
		3:
			draw_line(Vector2(0,h*.7),Vector2(w,h*.7),Color(1,1,1,.25),2)
			for k in range(5):draw_circle(Vector2(w*(.15+k*.18),h*.7),3,Color(1,1,1,.4))
