class_name Professionalism
extends RefCounted
## One knob for how well enemies do their job. Skill grows smoothly through a world: at 0.8 the dogs hesitate
## before shooting, rest longer between dashes, rarely use trenches and seldom storm; at 1.2 they aim fast,
## move in short dashes, sit in trenches and push the base. 1.0 is the tuning before this system existed.
## Enemy stats (HP, damage) are not touched: those stay in Campaign.hp_scale / damage_scale.
##
## A world lists its skill at the first and at the last combat room; boss rooms use the last value.
## New worlds keep the same wave structure and only add a row here (unknown worlds reuse world 1).
const WORLD_CURVE={1:[.8,1.2]}
## Values of every derived behaviour at skill .8 / 1.0 / 1.2; skill between them is interpolated,
## beyond 1.2 (endless) it extrapolates gently and is clamped by LIMITS.
const PROFILE={
	"aim_delay":[.38,.18,.06],      # seconds from lining up on a target to the first shot (visible glint)
	"pause":[1.3,1.0,.85],          # multiplier of the rest between dashes
	"trench_share":[.15,.35,.5],    # share of soldiers sent to a trench
	"assault_chance":[.25,.4,.55],  # chance an attention check turns into a storm of the base
}
const LIMITS={"aim_delay":[.03,.5],"pause":[.75,1.4],"trench_share":[0.0,.6],"assault_chance":[.1,.7]}

static func skill(index:int)->float:
	if Campaign.endless:return minf(1.4,1.1+Campaign.cycle*.06+index*.01)
	var curve:Array=WORLD_CURVE.get(Campaign.world,WORLD_CURVE[1])
	var last=maxi(1,Campaign.BOSSES[0]-1)
	return lerpf(curve[0],curve[1],clampf(float(index)/last,0,1))+Campaign.challenge_level()*Campaign.CHALLENGE_SKILL

static func value(key:String,index:int)->float:
	var points:Array=PROFILE[key];var s=skill(index)
	var result=lerpf(points[0],points[1],(s-.8)/.2) if s<=1.0 else lerpf(points[1],points[2],(s-1.0)/.2)
	return clampf(result,LIMITS[key][0],LIMITS[key][1])

## Chevrons by the HP bar: 1 below 0.94, 2 up to 1.08, 3 above. In world 1: fields 1–2, 3–4, 5–6 and the boss.
static func tier(index:int)->int:
	var s=skill(index)
	return 1 if s<.94 else 2 if s<1.08 else 3

## Room of an arena (or 0 outside a run).
static func of(arena,key:String)->float:
	return value(key,maxi(0,int(arena.room_index)) if arena!=null else 0)
