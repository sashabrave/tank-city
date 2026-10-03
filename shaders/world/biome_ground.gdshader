shader_type spatial;
// Ground around the battle board (0.8): the map colour, a little darker on slopes and in hollows.
// shadows_disabled: the far, coarse sun shadow split drew the board and fences onto the ground as blocky
// rectangles at a low sun (author, 0.8.0); the relief reads from slope shading instead.
render_mode diffuse_lambert, specular_disabled, shadows_disabled;
uniform vec4 base_color : source_color = vec4(.55,.58,.48,1.0);
uniform vec4 patch_color : source_color = vec4(.48,.55,.40,1.0);
uniform vec4 accent_color : source_color = vec4(.66,.62,.50,1.0);
uniform float seed = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7))+seed)*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);
}
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment(){
 // One flat map colour (author, 0.8: no patches); slopes a touch darker so the relief still reads.
 vec3 color=base_color.rgb;
 float slope=1.0-clamp(world_normal.y,0.0,1.0);
 color*=1.0-slope*.6;
 color*=mix(.88,1.04,clamp((world_pos.y+1.4)*.6,0.0,1.0));
 ALBEDO=color;
 ROUGHNESS=1.0;
}
