shader_type spatial;
render_mode cull_back;
global uniform bool cozy_enabled;
global uniform float cozy_rim;
global uniform bool cozy_shiny;
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
// Painted hull = library surface «paint» (data/materials.json): painted steel, not plastic (2026-10-03).
uniform float paint_metallic = 0.25;
uniform float paint_roughness = 0.45;
uniform float paint_clearcoat = 0.5;
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
  // 4x4 atlas tiles (glTF UV = image space): (1,2) steel, (3,2) blued gunmetal,
  // (0,2)/(2,0)/(3,0) dark tracks and wheels. Previously only the camo tile was metal.
  vec2 tile=floor(clamp(UV,0.0,0.999)*4.0);
  float steel=atlas ? float(tile==vec2(1.0,2.0)) : 0.0;
  float gunmetal=atlas ? float(tile==vec2(3.0,2.0)) : 0.0;
  float tread=atlas ? float(tile==vec2(0.0,2.0) || tile==vec2(2.0,0.0) || tile==vec2(3.0,0.0)) : 0.0;
  float brushed=sin(local_point.y*720.0+sin(local_point.x*137.0))*.022;
  float shine=cozy_shiny ? 1.0 : 0.35;
  METALLIC=(steel*.92+gunmetal*.85+tread*.35)*shine+mask*paint_metallic*shine;
  ROUGHNESS=mix(surface_roughness,paint_roughness,mask);
  ROUGHNESS=mix(ROUGHNESS,.28+brushed,steel*shine);
  ROUGHNESS=mix(ROUGHNESS,.36,gunmetal*shine);
  ROUGHNESS=mix(ROUGHNESS,.62,tread);
  // Steel keeps a light tint so it mirrors the pastel sky instead of reading as black.
  ALBEDO=mix(ALBEDO,max(ALBEDO,vec3(.58,.61,.62)),steel*shine);
  ALBEDO=mix(ALBEDO,max(ALBEDO,vec3(.26,.29,.32)),gunmetal*shine);
  ALBEDO*=1.0+brushed*steel*.65;
  // Toy-like lacquer on painted armour: soft highlight without changing the paint colour.
  if(cozy_shiny){CLEARCOAT=paint_clearcoat*(1.0-steel-gunmetal-tread);CLEARCOAT_ROUGHNESS=.35;}
  SPECULAR=.5+.2*shine;
  RIM=cozy_rim;RIM_TINT=.55;
 }
 EMISSION=signal+paint_color.rgb*flash*mask;
}
