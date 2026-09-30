shader_type spatial;
// Flat cozy ring for selection, radius and pickup markers.
// Soft line + faint inner fill; a slow highlight travels around, the ring gently breathes.
// urgency 1 = enemy danger: faster pulse and marching ticks.
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0,.8,.4,1.0);
instance uniform float outer = 1.15;
instance uniform float thickness = .1;
instance uniform float urgency = 0.0;
instance uniform float phase = 0.0;
void fragment(){
 vec2 p=(UV*2.0-1.0)*outer;
 float breathe=1.0+.018*sin(TIME*1.7+phase)*(1.0-urgency)+.03*sin(TIME*7.0+phase)*urgency;
 float r=length(p)/breathe;
 float angle=atan(p.y,p.x);
 float d=abs(r-1.0);
 float aa=fwidth(r)*1.2;
 float line=1.0-smoothstep(thickness*.5,thickness*.5+aa,d);
 float halo=exp(-d*14.0)*.28*(1.0-step(1.35,r));
 float fill=smoothstep(.2,1.0,r)*(1.0-smoothstep(1.0-aa,1.0,r))*.13;
 // Travelling highlight (calm) or marching ticks (danger).
 float sweep=.5+.5*sin(angle*2.0-TIME*(1.1+urgency*2.5)+phase);
 float ticks=step(.5,fract(angle*3.8197-TIME*.9));
 float shimmer=mix(.78+.32*pow(sweep,3.0),.55+.45*ticks,urgency);
 float pulse=.92+.08*sin(TIME*2.2+phase)+urgency*.18*sin(TIME*9.0+phase);
 ALBEDO=tint.rgb*(1.05+.35*pow(sweep,4.0)*(1.0-urgency));
 ALPHA=clamp((line*shimmer+halo+fill)*pulse*tint.a,0.0,1.0);
}
