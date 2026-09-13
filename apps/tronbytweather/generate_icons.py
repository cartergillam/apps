"""Deterministic transparent pixel icons. No external assets or network."""
from pathlib import Path
import base64
from PIL import Image, ImageDraw
root=Path(__file__).parent/'icons'
constants=[]
for name in ['clear','partly_cloudy','cloudy','rain','heavy_rain','snow','heavy_snow','fog','thunderstorm','unknown','freezing_rain','moon','night_partly']:
    im=Image.new('RGBA',(20,20));d=ImageDraw.Draw(im)
    if name in ('clear','partly_cloudy'):
        for a,b in [((10,0),(10,3)),((10,16),(10,19)),((0,10),(3,10)),((16,10),(19,10)),((3,3),(5,5)),((15,15),(17,17)),((3,17),(5,15)),((15,5),(17,3))]: d.line((a,b),fill='#ffce45',width=2)
        d.ellipse((5,5,14,14),fill='#ffce45')
    if name in ('moon','night_partly'):
        d.ellipse((3,2,16,17),fill='#e0edf5');d.ellipse((8,0,19,13),fill=(0,0,0,0))
    if name not in ('clear','unknown','moon'):
        y=6 if name in ('partly_cloudy','night_partly') else 3
        d.ellipse((2,y+2,10,y+10),fill='#e0edf5');d.ellipse((7,y,16,y+10),fill='#e0edf5');d.ellipse((12,y+3,19,y+10),fill='#e0edf5');d.rectangle((3,y+7,17,y+10),fill='#e0edf5')
    if name in ('rain','heavy_rain','freezing_rain'):
        for x in (4,10,16):d.line((x,15,x-1,18),fill='#4dbbff',width=2)
        if name=='heavy_rain':d.point((7,19),fill='#4dbbff');d.point((13,19),fill='#4dbbff')
        if name=='freezing_rain':d.line((8,17,12,17),fill='white');d.line((10,15,10,19),fill='white')
    if name in ('snow','heavy_snow'):
        for x in (4,10,16):d.line((x-1,17,x+1,17),fill='white');d.line((x,16,x,18),fill='white')
        if name=='heavy_snow':d.point((7,14),fill='white');d.point((13,14),fill='white')
    if name=='fog':
        for y in (15,18):d.line((2,y,17,y),fill='#b0c6d5',width=1)
    if name=='thunderstorm':d.polygon([(11,12),(7,16),(10,16),(8,19),(15,14),(11,14)],fill='#ffce45')
    if name=='unknown':
        d.rectangle((5,3,14,5),fill='#b0c6d5');d.rectangle((12,5,14,9),fill='#b0c6d5');d.rectangle((9,8,13,10),fill='#b0c6d5');d.rectangle((9,10,10,13),fill='#b0c6d5');d.rectangle((9,16,10,17),fill='#b0c6d5')
    im.save(root/(name+'.png'))

    constants.append(name.upper()+' = "'+base64.b64encode((root/(name+'.png')).read_bytes()).decode()+'"')
mapping={'CLEAR':'SUN','PARTLY_CLOUDY':'PARTLY','CLOUDY':'CLOUD','FREEZING_RAIN':'ICE','THUNDERSTORM':'STORM'}
constants=[mapping.get(line.split(' = ')[0],line.split(' = ')[0])+' = '+line.split(' = ',1)[1] for line in constants]
p=root.parent/'tronbyt_weather.star'
s=p.read_text(); a=s.index('# BEGIN BUNDLED ICONS'); b=s.index('# END BUNDLED ICONS',a)
p.write_text(s[:a]+'# BEGIN BUNDLED ICONS\n'+'\n'.join(constants)+'\n'+s[b:])
