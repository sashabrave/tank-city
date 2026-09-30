shader_type spatial;
render_mode diffuse_burley;
varying vec3 brick_position;
varying vec3 brick_normal;
void vertex() {
 brick_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 brick_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
float grain(vec3 p){return fract(sin(dot(floor(p*100.0),vec3(12.98,78.23,39.43)))*43758.5453);}
void fragment(){
 float row=floor(brick_position.y/.1875);
 float u=abs(brick_normal.x)>.5?brick_position.z:brick_position.x;
 float joint=step(.025,fract((u+mod(row,2.0)*.125)*4.0));
 if(abs(brick_normal.y)>.5){joint=1.0;}
 vec3 clay=vec3(.94,.57,.35)*(0.94+grain(brick_position)*.12);
 ALBEDO=mix(vec3(.50,.37,.28),clay,joint);
 ROUGHNESS=.94;
}
