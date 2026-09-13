#!/usr/bin/env python3
"""Offline fixtures + reusable nearest-neighbor review montages for all Overview apps."""
import base64,copy,io,json,re,subprocess,tempfile
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
root=Path(__file__).resolve().parents[2]
output=Path(tempfile.mkdtemp(prefix='tronbyt-overview-'))
for league,favorite,other,record,standing in [('nhl','TOR','BOS','32-18-6','#3 ATL'),('nba','LAL','BOS','42-21','WEST SEED 3'),('nfl','BUF','NE','10-6-1','#2 AFC E')]:
    live=(root/'apps'/(league+'live')/(league+'_live.star')).read_text()
    logos=re.findall(r'FIXTURE_(?:HOME_)?LOGO = "([^"]+)"',live)
    if league=='nhl':
        image=Image.open(root/'apps/nhlnextgame/images/tor.png').convert('RGBA')
        image.thumbnail((20,20),Image.Resampling.LANCZOS)
        buffer=io.BytesIO();image.save(buffer,format='PNG');logos[0]=base64.b64encode(buffer.getvalue()).decode()
    def team(abbr,index=0):return {'abbreviation':abbr,'providerId':str(index+1),'primaryColor':'#003E7E','logoData':logos[min(index,len(logos)-1)]}
    a,b=team(favorite),team(other,1)
    nextgame={'awayTeam':a,'homeTeam':b,'status':'scheduled','dateLabel':'JAN 10','timeLabel':'7:00PM'}
    lastgame={'awayTeam':a,'homeTeam':b,'status':'final','awayScore':4 if league=='nhl' else 120 if league=='nba' else 28,'homeScore':2 if league=='nhl' else 110 if league=='nba' else 21,'result':'W','finalLabel':'FINAL'}
    base={'team':a,'season':{'label':'2025-26','phase':'regular','record':{'display':record}},'standing':{'label':standing},'nextGame':nextgame,'lastGame':lastgame}
    cases={}
    def add(name,payload,count=1,style='dim'):cases[name]=(copy.deepcopy(payload),count,style)
    season={k:v for k,v in base.items() if k not in ['nextGame','lastGame']}
    add('team',season);add('next',{'nextGame':nextgame});add('last-win',{'lastGame':lastgame});add('rotation',base,3)
    for style in ['off','dim','full']:add('background-'+style,base,3,style)
    v=copy.deepcopy(season);v['team']['abbreviation']='LONGNAME';v['season']['record']['display']='99-99-99';v['standing']['label']='#16 WEST';add('long-extreme',v)
    v=copy.deepcopy(season);v['team']['logoData']=None;add('logo-missing',v)
    v=copy.deepcopy(base);v['stale']=True;add('stale',v,3)
    v=copy.deepcopy(season);v['season']['phase']='offseason';v['standing']=None;add('offseason',v)
    v=copy.deepcopy(season);v['season']={'phase':'preseason'};v['standing']=None;add('preseason',v)
    v=copy.deepcopy(season);v['season']={'phase':'regular','record':None};v['standing']=None;add('standings-unavailable',v)
    add('no-next',{k:v for k,v in base.items() if k!='nextGame'},2)
    for state in ['home','away','long-opponent','afternoon','postponed','delayed','missing-timestamp']:
        v=copy.deepcopy(nextgame)
        if state=='home':v['awayTeam'],v['homeTeam']=v['homeTeam'],v['awayTeam']
        if state=='long-opponent':v['homeTeam']['abbreviation']='WORSTLONG'
        if state=='afternoon':v['timeLabel']='1:00PM'
        if state in ['postponed','delayed']:v['status']=state
        if state=='missing-timestamp':v['dateLabel']=None;v['timeLabel']=None
        add('next-'+state,{'nextGame':v})
    for state in ['loss','tie','ot','so' if league=='nhl' else '2ot','high-score','logo-missing','bad-score']:
        v=copy.deepcopy(lastgame)
        if state=='loss':v['result']='L';v['awayScore'],v['homeScore']=v['homeScore'],v['awayScore']
        if state=='tie':v['result']='T';v['awayScore']=v['homeScore']
        if state in ['ot','so','2ot']:v['finalLabel']='FINAL/'+state.upper()
        if state=='high-score':v['awayScore']=199;v['homeScore']=188
        if state=='logo-missing':v['awayTeam']['logoData']=None;v['homeTeam']['logoData']=None
        if state=='bad-score':v['awayScore']='bad';v['homeScore']=None
        add('last-'+state,{'lastGame':v})
    for name,size in [('wide-logo',(20,5)),('tall-logo',(5,20))]:
        image=Image.new('RGBA',(20,20));image.paste(Image.new('RGBA',size,(255,255,255,255)),((20-size[0])//2,(20-size[1])//2));buffer=io.BytesIO();image.save(buffer,format='PNG')
        v=copy.deepcopy(season);v['team']['logoData']=base64.b64encode(buffer.getvalue()).decode();add(name,v)
    add('null',None);add('partial',{'team':a,'record':None,'standings':None,'games':None,'nextGame':None,'lastGame':None})
    add('null-opponent',{'team':None,'nextGame':{'awayTeam':None,'homeTeam':{}},'lastGame':{'opponent':None}})
    directory=output/league;directory.mkdir()
    app=root/'apps'/(league+'overview')/(league+'_overview.star')
    for name,(payload,count,style) in cases.items():
        path=directory/(name+'.webp')
        subprocess.run(['pixlet','render',str(app),'$overview_data='+json.dumps(payload),'team_color_background_style='+style,'--output',str(path)],check=True)
        with Image.open(path) as im:
            assert im.size==(64,32),(name,im.size)
            assert im.n_frames==count,(league,name,im.n_frames,count)
            for frame in range(count):
                im.seek(frame);assert im.size==(64,32)
                im.convert('RGB') # Decode every frame, including rotation boundaries.
            if count>1:
                # WebP metadata uses frame timestamps; Pillow populates duration after load.
                im.seek(0);im.load();assert im.info['duration']==5000
    # Background styles and pathological logo aspect ratios cannot move text.
    with Image.open(directory/'team.webp') as original:
        text_area=original.convert('RGB').crop((24,0,64,25))
        for name in ['background-off','background-full','wide-logo','tall-logo','logo-missing']:
            with Image.open(directory/(name+'.webp')) as candidate:
                assert ImageChops.difference(text_area,candidate.convert('RGB').crop((24,0,64,25))).getbbox() is None,(league,name,'text moved')
    for name in ['team','next','last-win','last-high-score','next-postponed']:
        with Image.open(directory/(name+'.webp')) as im:
            assert im.convert('RGB').crop((0,31,64,32)).getbbox() is None,(league,name,'bottom edge clipping')
    # Common template remains identical across leagues; only identity/schema differ.
    assert 'http.star' not in app.read_text() and 'https://' not in app.read_text()
    subprocess.run(['pixlet','schema',str(app),'--output',str(directory/'schema.json')],check=True)
    schema=json.loads((directory/'schema.json').read_text())
    assert len(schema['schema'][0]['options'])==(30 if league=='nba' else 32)
    selected=[('team',0),('next',0),('last-win',0),('last-ot',0),('last-so' if league=='nhl' else 'last-2ot',0),('last-tie',0),('logo-missing',0),('stale',0),('offseason',0),('preseason',0),('last-high-score',0),('next-postponed',0),('background-off',0),('background-full',0),('standings-unavailable',0),('next-missing-timestamp',0),('wide-logo',0),('tall-logo',0),('null',0),('partial',0),('last-logo-missing',0)]
    montage=Image.new('RGB',(816,165*((len(selected)+2)//3)),(24,24,24));draw=ImageDraw.Draw(montage)
    for i,(name,frame) in enumerate(selected):
        with Image.open(directory/(name+'.webp')) as im:
            im.seek(frame);x=i%3*272;y=i//3*165;draw.text((x+8,y+5),name,fill='white');montage.paste(im.convert('RGB').resize((256,128),Image.Resampling.NEAREST),(x+8,y+25))
    montage.save('/tmp/'+league+'-overview-review.png')
    print(f'{league.upper()}: {len(cases)} fixtures passed, exact 64x32, 5-second useful-page rotation; {directory}',flush=True)
print('Overview render artifacts: '+str(output))
