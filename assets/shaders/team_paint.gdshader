shader_type spatial;
render_mode cull_back;
global uniform bool cozy_enabled;
uniform sampler2D color_texture : source_color, filter_linear_mipmap;
uniform sampler2D signal_texture : source_color, filter_linear_mipmap;
uniform bool atlas = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 paint_color : source_color = vec4(0.86,0.85,0.77,1.0);
uniform bool barrel_white = false;
uniform float barrel_end = 100.0;
uniform bool striped = false;
uniform float flash = 0.0;
uniform float surface_roughness = 0.85;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
 vec3 base=base_color.rgb;
 float mask=1.0;
 vec3 signal=vec3(0.0);
 if(atlas){
  base*=texture(color_texture,UV).rgb;
  signal=texture(signal_texture,UV).rgb;
  // glTF flips Blender's V: ivory is tile (2,0) in a 4x4 atlas.
  mask=step(0.5,UV.x)*(1.0-step(0.75,UV.x))*step(0.75,UV.y);
 }
 vec3 paint=paint_color.rgb;
 if(striped){paint=mix(paint,vec3(0.045,0.05,0.048),step(0.5,fract((local_point.x+local_point.y)*15.0)));}
 ALBEDO=mix(base,paint,mask);
 if(barrel_white && local_point.z<barrel_end){ALBEDO=mix(ALBEDO,vec3(0.86,0.85,0.77),step(0.03,dot(base,vec3(0.333))));}
 ROUGHNESS=surface_roughness;
 if(cozy_enabled){
  float steel=atlas ? step(.25,UV.x)*(1.0-step(.5,UV.x))*step(.25,UV.y)*(1.0-step(.5,UV.y)) : 0.0;
  METALLIC=steel*.9;
  float brushed=sin(local_point.y*720.0+sin(local_point.x*137.0))*.022;
  ROUGHNESS=mix(mix(surface_roughness,.5,mask),.34+brushed,steel);
  ALBEDO*=1.0+brushed*steel*.65;
 }
 EMISSION=signal+paint_color.rgb*flash*mask;
}
