from PIL import Image, ImageDraw
from pathlib import Path
import random, subprocess, shutil, json, math
root=Path(__file__).resolve().parent.parent
random.seed(388)
colors={'plaster':(214,205,191),'grass':(155,165,116),'asphalt':(160,155,160),'wood':(174,146,117),'brick':(177,145,121),'roof':(193,160,139),'pavement':(196,186,169),'tile':(210,215,202)}
for name,base in colors.items():
    im=Image.new('RGB',(128,128));p=im.load()
    for y in range(128):
        for x in range(128):
            n=random.randint(-18,18)
            if name=='wood': n+=int(math.sin(x*.43)*15)
            if name=='grass': n=random.choice([-34,-16,0,5,22])
            p[x,y]=tuple(max(0,min(255,v+n)) for v in base)
    d=ImageDraw.Draw(im)
    if name=='brick':
        for y in range(0,128,24):
            d.line((0,y,128,y),fill=(112,109,103),width=2)
            for x in range(-24 if y%48 else 0,128,48):d.line((x,y,x,y+24),fill=(112,109,103),width=2)
    if name in ('pavement','tile'):
        for n in range(0,128,32):
            d.line((n,0,n,128),fill=(147,142,130),width=1)
            d.line((0,n,128,n),fill=(147,142,130),width=1)
    if name=='roof':
        for x in range(0,128,16):d.line((x,0,x,128),fill=(123,100,88),width=3)
        for y in range(0,128,32):d.line((0,y,128,y),fill=(145,112,96),width=2)
    im.save(root/'assets'/'textures'/f'{name}.png')
src=Path(r'C:\Users\arthu\Desktop\BONDA PROJECT\audio')
ff=shutil.which('ffmpeg')
for name in ['dedadao','douglas_e_eu','douglas_e_ele','condominio_life','tiro_de_nine']:
    target=root/'audio'/f'{name}.ogg'
    if not target.exists():
        r=subprocess.run([ff,'-y','-hide_banner','-loglevel','error','-i',str(src/f'{name}.mp3'),'-af','loudnorm=I=-18:TP=-2:LRA=9','-ar','44100','-c:a','libvorbis','-q:a','5',str(target)],capture_output=True,text=True)
        if r.returncode:raise RuntimeError(r.stderr)
    print('AUDIO_OK',name,flush=True)
print('ASSETS_OK')
