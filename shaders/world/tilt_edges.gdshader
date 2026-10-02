shader_type canvas_item;
render_mode unshaded;
// Toy tilt-shift for a near-vertical camera: a sharp focus band slightly below centre,
// blur grows smoothly toward top and bottom. 12-tap golden-angle disk on mip 1 — soft bokeh,
// no stepped mip levels. Radius is relative to screen height, so retina looks the same.
uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap;
uniform float focus_center = .54;
uniform float focus_width = .15;
uniform float falloff = .34;
uniform float max_radius = .011;
void fragment() {
 float d=abs(SCREEN_UV.y-focus_center);
 float t=smoothstep(focus_width,focus_width+falloff,d);
 t*=t;
 vec3 sharp=textureLod(scene_texture,SCREEN_UV,0.0).rgb;
 if(t<.01){COLOR=vec4(sharp,1.0);}
 else{
  float aspect=SCREEN_PIXEL_SIZE.x>0.0 ? SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x : 1.0;
  vec2 radius=vec2(max_radius*t/aspect,max_radius*t);
  vec3 sum=sharp;float weight=1.0;
  for(int i=0;i<12;i++){
   float fi=float(i)+.5;
   float r=sqrt(fi/12.0);float a=fi*2.39996;
   vec2 offset=vec2(cos(a),sin(a))*r*radius;
   // Keep taps inside the frame: samples past the edge smeared a light band with an oval bulge (T-075).
   vec2 uv=clamp(SCREEN_UV+offset,SCREEN_PIXEL_SIZE*3.0,1.0-SCREEN_PIXEL_SIZE*3.0);
   sum+=textureLod(scene_texture,uv,1.0).rgb;weight+=1.0;
  }
  vec3 soft=sum/weight;
  // Miniature look: slightly richer colour where it is out of focus.
  float luma=dot(soft,vec3(.299,.587,.114));
  soft=mix(vec3(luma),soft,1.0+.1*t);
  COLOR=vec4(mix(sharp,soft,clamp(t*1.1,0.0,1.0)),1.0);
 }
}
