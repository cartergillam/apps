#!/usr/bin/env python3
"""Reproduce standalone Overview apps from one common layout; Live is read-only."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[2]
template=(Path(__file__).parent/'overview.star.template').read_text()
for league,default in [('nhl','10'),('nba','13'),('nfl','2')]:
    directory=root/'apps'/(league+'overview');directory.mkdir(exist_ok=True)
    live=(root/'apps'/(league+'live')/(league+'_live.star')).read_text()
    options=live[live.index('def team_options():'):]
    source=template.replace('__LEAGUE__',league.upper()).replace('__DEFAULT__',default).replace('__TEAM_OPTIONS__',options)
    app=directory/(league+'_overview.star');app.write_text(source)
    subprocess.run(['pixlet','format',str(app)],check=True)
    (directory/'manifest.yaml').write_text(f'''---
id: {league}-overview
name: {league.upper()} Overview
summary: Team season and games
desc: Team record and standings, the next matchup and last result. Uses server-managed sports data and saved device timezone.
author: Tronbyt
fileName: {league}_overview.star
packageName: {league}overview
recommendedInterval: 5
category: sports
tags:
  - {league}
  - sports
  - overview
published: '2026-09-13T00:00:00Z'
updated: '2026-09-13T00:00:00Z'
''')
