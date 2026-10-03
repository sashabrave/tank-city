shader_type spatial;
// Puffy out-of-focus clouds: camera-facing discs grouped into clusters (MultiMesh).
// Lit top, lilac underside, blurred rim — a toy tilt-shift hint of a cloud, no noise textures.
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 light_color : source_color = vec4(1.0,.99,.97,1.0);
uniform vec4 shade_color : source_color = vec4(.80,.80,.90,1.0);
uniform float opacity = .9;
// Battle edge clouds: fade out toward the top and bottom of the screen, where the tilt-shift blur turned
// them into light smudges at the frame edges (sides too: a bright blob sat on the right at night). 0 keeps them everywhere (route map).
uniform float screen_edge_fade = 0.0;
varying vec2 corner;
varying float blur;
void vertex(){
 corner=VERTEX.xy*2.0;
 blur=INSTANCE_CUSTOM.x;
 vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 float size=length(MODEL_MATRIX[0].xyz);
 origin.y+=sin(TIME*.25+INSTANCE_CUSTOM.y*6.283)*.12;
 POSITION=PROJECTION_MATRIX*(VIEW_MATRIX*vec4(origin,1.0)+vec4(VERTEX.xy*size,0.0,0.0));
}
void fragment(){
 float r=length(corner);
 float edge=1.0-smoothstep(1.0-mix(.3,.7,blur),1.0,r);
 float light=smoothstep(-.75,.65,corner.y);
 ALBEDO=mix(shade_color.rgb,light_color.rgb,light);
 float band=smoothstep(.06,.4,SCREEN_UV.y)*smoothstep(.94,.6,SCREEN_UV.y)*smoothstep(.0,.22,SCREEN_UV.x)*smoothstep(1.0,.78,SCREEN_UV.x);
 ALPHA=edge*opacity*mix(1.0,band,screen_edge_fade);
}
