shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform int kind = 0;
uniform bool night = false;
uniform bool near_bokeh = false;
uniform float strength = 1.0;
varying float phase;
void vertex() {
 phase = INSTANCE_CUSTOM.x;
 vec3 origin = MODEL_MATRIX[3].xyz;
 origin.x += sin(TIME*.12+phase*31.0)*.7 + sin(TIME*.055+phase*9.0)*.8;
 origin.y += sin(TIME*.23+phase*20.0)*.35;
 origin.z += cos(TIME*.1+phase*24.0)*.6;
 vec2 size = VERTEX.xy * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
 POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(origin, 1.0) + vec4(size,0.0,0.0));
}
void fragment() {
 vec2 p = (UV-.5)*2.0;
 float soft = exp(-dot(p,p)*3.8)*(1.0-smoothstep(.55,1.0,length(p)));
 float pulse = .4+.6*pow(.5+.5*sin(TIME*.65+phase*40.0),3.0);
 vec3 color=vec3(.93,.95,.90);
 float opacity=.17;
 if(kind==0 && near_bokeh){
  // Large near-field discs: diffuse edges, no bright pin-point or hard outline.
  soft=exp(-dot(p,p)*2.2)*(1.0-smoothstep(.28,1.0,length(p)));
  opacity=mix(.075,.14,phase);
 }
 if(kind==1){color=vec3(.81,.96,.46);opacity=night ? .48*pulse : 0.0;}
 if(kind==2){color=night ? vec3(.42,.48,.29) : vec3(.58,.55,.30);soft*=1.0-smoothstep(.18,.75,abs(p.y));opacity=.38;}
 ALBEDO=color;EMISSION=color*(kind==1 ? .65 : 0.0);ALPHA=soft*opacity*strength;
}
