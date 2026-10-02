extends Node
## Test guard: active only when a scene from tests/ is launched. A failed assert or any script error
## used to leave headless Godot hanging until an outside watchdog killed it; the guard ends the run at
## once with exit code 1 ("TEST ABORTED"). A hung test is stopped after --test-timeout=<seconds>
## (default 180) with exit code 124. Normal play never creates the logger.
const DEFAULT_TIMEOUT=180.0
var limit=DEFAULT_TIMEOUT
var started=0
var stopping=false
class Watch extends Logger:
	var guard
	func _init(owner):guard=owner
	func _log_error(_function:String,file:String,line:int,_code:String,rationale:String,_editor_notify:bool,error_type:int,_backtraces:Array[ScriptBacktrace])->void:
		if error_type==ERROR_TYPE_SCRIPT:guard.call_deferred("abort","%s (%s:%d)" % [rationale,file,line])
func _ready():
	var args=Array(OS.get_cmdline_args())
	if not args.any(func(a):return str(a).begins_with("tests/") or str(a).begins_with("res://tests/")):set_process(false);return
	for a in Array(OS.get_cmdline_user_args())+args:
		if str(a).begins_with("--test-timeout="):limit=float(str(a).get_slice("=",1))
	process_mode=Node.PROCESS_MODE_ALWAYS;started=Time.get_ticks_msec()
	OS.add_logger(Watch.new(self))
func abort(reason:String):
	if stopping:return
	stopping=true;printerr("TEST ABORTED: script error — "+reason);get_tree().quit(1)
func _process(_delta):
	if not stopping and Time.get_ticks_msec()-started>limit*1000.0:
		stopping=true;printerr("TEST TIMEOUT after %d s" % int(limit));get_tree().quit(124)
