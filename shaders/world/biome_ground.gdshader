shader_type spatial;
// Ground around the battle board (0.8): soft biome patches from world-space value noise, darker on slopes
// and in hollows. No textures; three palette colours per biome come from BackdropGround.
render_mode diffuse_lambert, specular_disabled;
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
 vec2 p=world_pos.xz;
 float big=noise(p*.09)*.65+noise(p*.23)*.35;
 vec3 color=mix(base_color.rgb,patch_color.rgb,smoothstep(.42,.62,big));
 // Small accent spots (sand, dry grass, ash) and fine speckle so large areas are not flat.
 float spots=noise(p*.55+17.0);
 color=mix(color,accent_color.rgb,smoothstep(.68,.78,spots)*.8);
 color*=.94+.12*noise(p*2.3);
 // Slopes and low ground read a little darker: shape without extra lights.
 float slope=1.0-clamp(world_normal.y,0.0,1.0);
 color*=1.0-slope*.9;
 color*=mix(.88,1.04,clamp((world_pos.y+1.4)*.6,0.0,1.0));
 ALBEDO=color;
 ROUGHNESS=1.0;
}
