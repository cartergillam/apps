#!/usr/bin/env python3
"""Offline Weather product fixtures: no geocoding/weather/icon HTTP calls."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
from PIL import Image, ImageChops
root = Path(os.environ.get('TRONBYT_WEATHER_OUTPUT', tempfile.mkdtemp(prefix='tronbyt-weather-')))
app = 'apps/tronbytweather/tronbyt_weather.star'
base = {'current': {'temperature':25,'feelsLike':27,'condition':'clear'}, 'daily':[
    {'weekday':'Sat','high':25,'low':14,'condition':'clear'},
    {'weekday':'Sun','high':19,'low':12,'condition':'rain'},
    {'weekday':'Mon','high':20,'low':11,'condition':'cloudy'}], 'stale':False}
fixtures = {}
for condition in ['clear','mostly_clear','partly_cloudy','cloudy','rain','heavy_rain','snow','heavy_snow','thunderstorm','fog','freezing_rain','unknown']:
    value=copy.deepcopy(base);value['current']['condition']=condition
    if condition in ('snow','heavy_snow'):
        value['current'].update(temperature=-6,feelsLike=-10);value['daily'][0].update(high=-3,low=-12)
    if condition=='freezing_rain':
        value['current'].update(temperature=-1,feelsLike=-4);value['daily'][0].update(high=1,low=-5)
    fixtures[condition]=(value,'current','metric',1)
for name,t,feels in [('cold',-30,-38),('minus9',-9,-12),('zero',0,-2),('nine',9,7),('normal',25,27),('heat',40,47),('humid',32,41)]:
    value=copy.deepcopy(base);value['current'].update(temperature=t,feelsLike=feels);value['daily'][0].update(high=t+3,low=t-7);fixtures[name]=(value,'current','metric',1)
    imperial=copy.deepcopy(value)
    for key in ['temperature','feelsLike']:imperial['current'][key]=imperial['current'][key]*9/5+32
    for day in imperial['daily']:
        for key in ['high','low']:day[key]=day[key]*9/5+32
    fixtures[name+'-f']=(imperial,'current','imperial',1)
for name,kind,timing,prob in [('rain-soon','RAIN','WITHIN 1 HR',.7),('snow-soon','SNOW','IN ~2 HR',.6),('now','RAIN','NOW',None)]:
    value=copy.deepcopy(base);value['soon']={'kind':kind,'timing':timing,'probability':prob}
    if kind=='SNOW':value['current'].update(temperature=0,feelsLike=-3);value['daily'][0].update(high=2,low=-6)
    if timing=='NOW':value['current']['condition']='rain'
    fixtures[name]=(value,'auto','metric',3)
fixtures['auto']=(copy.deepcopy(base),'auto','metric',2)
for condition in ('clear','partly_cloudy'):
    value=copy.deepcopy(base);value['current'].update(condition=condition,daytime=False);fixtures['night-'+condition]=(value,'current','metric',1)
for condition in ('clear','partly_cloudy'):
    value=copy.deepcopy(base);value['current'].update(condition=condition,daytime=True);fixtures['day-'+condition]=(value,'current','metric',1)
value=copy.deepcopy(base);value['current']['daytime']=None;fixtures['missing-daytime']=(value,'current','metric',1)
value=copy.deepcopy(base);value['current'].update(temperature=-148,feelsLike=-238);value['daily'][0].update(high=-130,low=-148);fixtures['polar-f']=(value,'current','imperial',1)
fixtures['forecast']=(copy.deepcopy(base),'forecast','metric',1)
value=copy.deepcopy(base)
for i,day in enumerate(value['daily']):day.update(high=-9-i*3,low=-20-i*5,condition=['snow','freezing_rain','fog'][i])
fixtures['winter-forecast']=(value,'forecast','metric',1)
value=copy.deepcopy(base);value['stale']=True;value['soon']={'kind':'RAIN','timing':'WITHIN 1 HR','probability':.7};fixtures['stale']=(value,'auto','metric',2)
fixtures['null-soon'] = ({'current':base['current'],'daily':[None],'soon':{'kind':None,'timing':None,'probability':None}},'auto','metric',3)
fixtures['null'] = ({'current':None,'daily':None,'hourly':None},'auto','metric',1)
fixtures['partial'] = ({'current':{'temperature':0,'feelsLike':None,'condition':None},'daily':None},'auto','metric',1)
fixtures['daily-only'] = ({'current':None,'daily':base['daily']},'auto','metric',1)
for name,(value,mode,units,count) in fixtures.items():
    path=root/(name+'.webp')
    subprocess.run(['pixlet','render',app,'$provider_data='+json.dumps(value),'mode='+mode,'units='+units,'--max_duration','30000','--output',str(path)],check=True)
    with Image.open(path) as im:
        assert im.size==(64,32),(name,im.size)
        assert im.n_frames==count,(name,im.n_frames,count)
        for index in range(im.n_frames):
            im.seek(index);assert im.size==(64,32)
            frame=im.convert('RGB')
            assert frame.crop((63,0,64,32)).getbbox() is None,(name,'right edge clipping')
            assert frame.crop((0,31,64,32)).getbbox() is None,(name,'bottom clipping')
for name,error in [('missing-location',{'code':'weather_location_missing'}),('unavailable',{'code':'provider_temporarily_unavailable'})]:
    subprocess.run(['pixlet','render',app,'$provider_error='+json.dumps(error),'--output',str(root/(name+'.webp'))],check=True)
# All icons remain in the fixed 20x20 canvas. Forecast cells retain equal width.
for path in Path('apps/tronbytweather/icons').glob('*.png'):
    with Image.open(path) as im:
        assert im.size==(20,20) and im.mode=='RGBA'
        assert im.getpixel((0,0))[3]==0
with Image.open(root/'clear.webp') as a, Image.open(root/'rain.webp') as b:
    assert ImageChops.difference(a.convert('RGB').crop((24,0,64,25)),b.convert('RGB').crop((24,0,64,25))).getbbox() is None
print(f'Weather: {len(fixtures)+2} offline renders, fixed 64x32, bounded icons/text, extremes and AUTO page counts passed: {root}')

for name in ('day-clear','missing-daytime'):
    with Image.open(root/'clear.webp') as a, Image.open(root/(name+'.webp')) as b:
        assert ImageChops.difference(a.convert('RGB'),b.convert('RGB')).getbbox() is None
for condition in ('clear','partly_cloudy'):
    with Image.open(root/('day-'+condition+'.webp')) as a, Image.open(root/('night-'+condition+'.webp')) as b:
        assert ImageChops.difference(a.convert('RGB').crop((0,0,24,25)),b.convert('RGB').crop((0,0,24,25))).getbbox() is not None
        assert ImageChops.difference(a.convert('RGB').crop((24,0,64,32)),b.convert('RGB').crop((24,0,64,32))).getbbox() is None
print('Day/night icon changes preserve quote geometry; missing daytime uses deterministic daytime fallback')
