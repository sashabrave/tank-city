"""Slice the four approved generated icon sheets without regenerating their artwork."""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
from collections import deque

def split_components(im):
    rgba=np.array(im);mask=rgba[:,:,3]>8
    seen=np.zeros(mask.shape,dtype=bool);h,w=mask.shape
    layers=[np.zeros_like(rgba) for _ in range(9)]
    for y,x in zip(*np.nonzero(mask)):
        if seen[y,x]:continue
        queue=deque([(int(y),int(x))]);seen[y,x]=True;component=[]
        while queue:
            cy,cx=queue.popleft();component.append((cy,cx))
            for ny,nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
                if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;queue.append((ny,nx))
        if len(component)<24:continue
        ys,xs=np.array(component).T
        col=min(2,int(xs.mean()/(w/3)));row=min(2,int(ys.mean()/(h/3)))
        layers[row*3+col][ys,xs]=rgba[ys,xs]
    return [Image.fromarray(layer) for layer in layers]

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/icons-unified'
SHEETS=[
 ('v1',['pistol','smg','rifle','shotgun','heavy','rpg','grenade','turret','laser'],[0,400,810,1254],[[0,400,815,1254],[0,400,825,1254],[0,390,810,1254]]),
 ('v1',['recipe','alloy','barrier','star','heart','repair','vehicle_repair','vehicle','wall'],[0,420,790,1254],[[0,410,820,1254]]*3),
 ('v09',['damage','pressure','shield','health','speed','airstrike','alloy','ally_drone','cloak'],[0,440,815,1254],[[0,410,830,1254]]*3),
 ('v09',['comrade','core','fire','freeze','gas','mine','rescue','slots'],[0,445,805,1254],[[0,420,825,1254]]*3),
]
all_icons=[]
for number,(folder,names,ys,xrows) in enumerate(SHEETS,1):
    im=Image.open(OUT/f'sheets/sheet-{number}.png').convert('RGBA')
    assert im.size==(1254,1254)
    layers=split_components(im)
    for i,name in enumerate(names):
        icon=layers[i]
        bounds=icon.getbbox();assert bounds,(folder,name)
        assert bounds[0]>0 and bounds[1]>0 and bounds[2]<icon.width and bounds[3]<icon.height,(folder,name,bounds,icon.size)
        icon=icon.crop(bounds)
        icon.thumbnail((432,432),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,512));canvas.alpha_composite(icon,((512-icon.width)//2,(512-icon.height)//2))
        dest=OUT/'staged'/folder/f'{name}.png';dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest,optimize=True)
        all_icons.append((folder,name,canvas))
contact=Image.new('RGB',(7*190,5*220),'#20271f');draw=ImageDraw.Draw(contact)
for i,(folder,name,im) in enumerate(all_icons):
    x=(i%7)*190;y=(i//7)*220
    im=im.resize((174,174),Image.Resampling.LANCZOS);contact.paste(im,(x+8,y+4),im)
    draw.text((x+12,y+184),f'{folder}/{name}',fill='#e7ecdf')
contact.save(OUT/'contact-sheet.jpg',quality=95)
print(f'{len(all_icons)} icons sliced; 512x512 RGBA, 40px minimum padding, no clipped edges.')
