shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0,.84,.58,1.0);
uniform float density = .012;
void fragment(){
 float edge=pow(clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),.6);
 ALBEDO=tint.rgb;ALPHA=density*edge*(.2+.8*UV.y);
}
