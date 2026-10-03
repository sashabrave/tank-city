extends Node
## Probe: compare node names and types of two GLB scenes (args: dir a b).
func names(path)->Array:
	var root=load(path).instantiate();var out=[]
	for n in root.find_children("*","",true,false):out.append(str(root.get_path_to(n))+":"+n.get_class())
	out.sort();root.free();return out
func _ready():
	var a=OS.get_cmdline_user_args()
	var x=names(a[0]);var y=names(a[1])
	print("NAMES ",x.size()," vs ",y.size())
	for n in x:if n not in y:print("ONLY_A ",n)
	for n in y:if n not in x:print("ONLY_B ",n)
	get_tree().quit()
