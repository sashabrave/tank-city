shader_type spatial;
// Battle weather particles, all motion in the vertex stage.
// kind 0 rain streak, 1 snowflake, 2 sand streak (gusts), 3 low fog puff, 4 rain ripple (flat).
// Rain streaks are kept wider than a pixel of the scaled 3D buffer: sub-pixel lines made the FSR
// sharpening ring and read as black dashes. fall/slant/strength vary per rain style (weather.gd).
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform int kind = 0;
uniform float area = 16.0;
uniform bool night = false;
uniform float fall = 1.35;
uniform float slant = .9;
uniform float strength = 1.0;
varying vec2 corner;
varying float fade;
void vertex(){
 corner=UV*2.0-1.0;
 vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 float phase=INSTANCE_CUSTOM.x;float phase2=INSTANCE_CUSTOM.y;float rate=INSTANCE_CUSTOM.z;
 fade=1.0;
 if(kind==0){
  float life=fract(TIME*fall*rate+phase);
  origin.y=mix(6.5,-.1,life);origin.x+=life*slant;
  fade=smoothstep(0.0,.12,life)*(1.0-smoothstep(.9,1.0,life));
 }else if(kind==1){
  float life=fract(TIME*.085*rate+phase);
  origin.y=mix(6.0,0.0,life);
  origin.x+=sin(TIME*.9*rate+phase*20.0)*.35+life*.8;origin.z+=cos(TIME*.7+phase2*20.0)*.25;
  fade=smoothstep(0.0,.08,life)*(1.0-smoothstep(.93,1.0,life));
 }else if(kind==2){
  float life=fract(TIME*.55*rate+phase);
  origin.x=(life-.5)*area*1.2;origin.y=.12+phase2*1.6+sin(TIME*2.0+phase*9.0)*.12;
  // Gusts: the field fills with sand for a few seconds, then calms down.
  float gust=pow(.5+.5*sin(TIME*.33+phase2*1.3),3.0);
  fade=gust*smoothstep(0.0,.1,life)*(1.0-smoothstep(.85,1.0,life));
 }else if(kind==3){
  origin.x+=sin(TIME*.05*rate+phase*6.28)*1.5;origin.z+=cos(TIME*.04+phase2*6.28)*1.0;origin.y=.35+phase2*.5;
  fade=.75+.25*sin(TIME*.2+phase*6.28);
 }else{
  float life=fract(TIME*.9*rate+phase);
  origin.y=.03;fade=1.0-life;
  VERTEX.xy*=.3+life*.9;
 }
 if(kind==4){
  POSITION=PROJECTION_MATRIX*(VIEW_MATRIX*vec4(origin+vec3(VERTEX.x,0.0,VERTEX.y),1.0));
 }else{
  vec2 size=VERTEX.xy;
  POSITION=PROJECTION_MATRIX*(VIEW_MATRIX*vec4(origin,1.0)+vec4(size,0.0,0.0));
 }
}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);
 vec3 color=night ? vec3(.62,.68,.8) : vec3(.93,.95,1.0);
 float alpha=0.0;
 if(kind==0){alpha=smoothstep(1.0,.1,abs(p.x))*(.35+.65*(1.0-UV.y))*.36*strength;}
 else if(kind==1){alpha=(1.0-smoothstep(.45,1.0,r))*.95;}
 else if(kind==2){color=night ? vec3(.55,.5,.42) : vec3(.93,.82,.6);alpha=(1.0-abs(p.y))*(1.0-smoothstep(.4,1.0,abs(p.x)))*.55;}
 else if(kind==3){color=night ? vec3(.45,.5,.6) : vec3(.95,.96,.97);alpha=(1.0-smoothstep(.2,1.0,r))*.22;}
 else{float ring=1.0-smoothstep(.0,.16,abs(r-.8));alpha=ring*.4*step(r,1.0)*min(strength,1.3);}
 ALBEDO=color;ALPHA=alpha*fade;
}
