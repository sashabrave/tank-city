shader_type spatial;
render_mode diffuse_burley;
// Geometry carries the bricks: COLOR.rgb is clay or mortar, COLOR.a is the brick id (0 = mortar).
uniform bool section_tint=true;
uniform vec3 clay_tint=vec3(1.0);
varying vec3 brick_position;
varying vec3 section_origin;
void vertex() {
 brick_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 section_origin=MODEL_MATRIX[3].xyz;
}
float hash(vec3 p){return fract(sin(dot(p,vec3(12.98,78.23,39.43)))*43758.5453);}
void fragment(){
 float grain=hash(floor(brick_position*100.0));
 float brick=COLOR.a;
 // Per-wall variation so identical meshes do not repeat the same tint pattern.
 float tint=brick>0.0&&section_tint?0.88+hash(floor(section_origin*8.0)+brick*17.0)*0.24:1.0;
 ALBEDO=COLOR.rgb*(brick>0.0?clay_tint:vec3(1.0))*tint*(0.92+grain*(brick>0.0?0.14:0.08));
 ROUGHNESS=brick>0.0?.92:.98;
}
