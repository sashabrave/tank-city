shader_type canvas_item;
// Text that does not fit fades out toward its right edge (T-198) instead of «…» or a smaller font.
uniform float width=100.0;
uniform float fade=28.0;
varying vec2 local;
void vertex(){local=VERTEX;}
void fragment(){COLOR.a*=clamp((width-local.x)/max(fade,1.0),0.0,1.0);}
