"""NBA Live renders normalized sports data injected by tronbyt-server."""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

FONT = "CG-pixel-3x5-mono"
FIXTURE_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAC50lEQVR4nOSUXWhbZRjHf+/JyXdOkzRpmyWNNovSrm502uEHZFpl4LyYVyKIF6IX3jmd80IYTLADES86/NiN1/ZitJsX2oJCnVPHOrq5Dbd1tjG6VtKdJM2n+WhyzitRB0VavOmFsP/l+/D83z/v83sfhS3WXWioblaQUu7NZlYO55bP7S0WMj6Px1/2hYZnw9H4cSHE9GZ9YqPDhiGPXv7mxNHy4oeWkn4T04S+HqhbItSDr7Dz8SNjoaDjzf9MKKXsA16/Nff+G+aNt7lHA3c/OGxQW4Oejt/JFkbRZ9OHTFP6hOArwGq2bwSLoijfi3VmimGYcyc/vvRgfu4QLz1/nkvX76XWUDENhftiOgupLjAVTFr4dh3BFdmHRbQoFqr09gWIDXbtXz+UR/N6NXLqxDSJPfPML24jHs0im4JQsES54sRsKXjcdQJamfzCFI1qiZbRxKVZcXZYK0BS+SddNzAxfny2e3dsms6eFp9N7iGZCjB+ahi7o8X8zW4uXonSFagwNbObczMFZk6eZ3zsLGZTIhTxK1C/k/CFpYX8tjOnL7DvgMKtJY1GXeXrs/24HE2uXQvx49VeRhKLpFe8NBsCj0/j2VefYngkzpnTV+kJe+9fq7e+s0gpR8vF2rEPXpsUsZ1R3H4b1vplrHaDWDTPgad/Ip3xEo/r9IZKZLIenkwkWfxZ5cr17Tzz4i7CsQCdQZ8qVDnZnvJQYfUPhhJ9tcFHtlPL2J3D6ns8NLSMXQWbAwZ26ORWwe+CwYEVMMDRf5jPv9BYq0JsRxiEMWGzWQ8KKWW8/Yx3EAReXvrh4Ggw9xGrNYgE/66Wq2BK8DrhtnU/7scmP3HbXYXby4VwKOqbEkJM/MWhECL5LzaP5YpNkZrT3hHlTy1SzxDxg80CvxU1sp7ncA28O6Y53RuCveFPaasp5RO/3Lj4Vjr1bUJTdK/N2VlR/Q9fiDwwMtahii8369ty/f/X15Yb/hkAAP//DjobkoAsgEoAAAAASUVORK5CYII="
FIXTURE_HOME_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAEN0lEQVR4nGyVX1BUVRzHP/fP7r3sAsLuiiniACJMZKJGGBGiZDnTg2NaCjNl/94qa3poxgdHlCzHmho1661p7EEZxhq1JuQFc9SiBkX8g1E4C8iOEbDsIuw/7r2nubsOQvh72rPn/D7n/H7f7zlX5WFxsCqDhFqHJG9DsBLL8CAEKGoQIbowzWZINLHvj/H/p0pzYI01dchyo67py2JGAllIvF++mRxXFkevnGEoGiLD6WJsMtwL0h52t52YmS7PhlUfRpVP2LBdT76MLjmwTIPeYICRSJihiTHKvAXUl6wFzCIk8zj7ao7MRCgzYZ7s+e9lO9IZC48wzzWPdGcagdEBDFlBV53cHLzBxmWVtPovE45MUFtQzqRirpl8yufjXH/LA2BjTZ2i6599Wv0G0USMntF+BifHeH3Fc7j1DAzLoCh7Ef6JIFV5y2npucSOVS9Q7Mkl1+Xh6vDtCmoL/6LNf0NJCmDKTUJY3qGJMC+WVDE+FUNTHCiSjD/0D51DvfQEA3jSMvg3EqI8txRdcfB1x2muDfchLBMEZazNOaYSk+oWeRYsW+L20d7XyeC9YfY+8yqt/g5+DXSzp3oHfwcHeXrxY8kNXjl9gIVuLwnTAGFS6ltKdd5yTt1uL7o7HKhXqMk9+GxRReHqnCIuj/gp9iymPfAn5/s6adrawLbSdWwoeIIS7xKKvXmkO3QOXfgOp+7mUV8+GwpWMx6P4HJq9I70u1RUbWVrbwfxvBW8s3oTj7iz+erKjyAssvT0Oa5alOEDWU5CthRXcWt0gO97LhK3DHDoZRL715tJ+xhToDpwOXQikRAYCXZUvMSxTbtmAbf/sI9me0NVQ9XcGEYcJAUk29JCqNP+Vp1gmUl7vFlZxzzNza2Rfn67c4PKvOXJVRcHrhGdirN7w9v4Q3dpuvXLDFgqVARBZHxYAllRObmlgfX5q6YXRO0T3I/S+fmc2f7J9Lh8YTEftH4JiiN154QUlJHoQk6OyNRcrFiwdFaJaao2/duTljlr7vmlFUh2ZfY9txlCdMlYNKeqlglNhviivXmOEOHYBMHonHeAQ7+fREzFZ5QsmlXMySZk94cochGG4MKd67OSmm62MRAeYjQ6TuXiUjaXVE/PtQe6UzBFAtPqxYicUDgfiFNbOIIib7UbMRQJoSkqTkXhm86feffsYbzuLB7PKeC1Ux+TpWfgdWXy7dUWjne3IZJAGQyxk72XOh7I89G6I2iOnSQMkhaSFbC9JSt4XNmcrT/AWz99zvVAN4rmxrTFUlRwqpAwj7K7bSezXptzfS2sy/eiKmtQ7v8tq8neRmMTDMfusbGwnLa+K6lTOdTUyaasaRgPfWD319aDaEz21A5L2AZIetTh0JjCTK2ze2bRwJ5zx2emzwXa0VCRieqqB2kbklQGwpMSkSCS1IWwmm0BHvYJ+C8AAP//dnmdUo0QYVoAAAAASUVORK5CYII="

def main(config):
    scenario = config.get("_fixture_scenario", "")
    snapshot = fixture_snapshot(scenario)
    if snapshot == None:
        raw = config.get("$sports_data", "")
        if raw == "":
            return render.Root(child = neutral_page(provider_error(config)))
        snapshot = json.decode(raw)

    snapshot = dict_or_empty(snapshot)

    mode = text_or(config.get("mode", "favorite"), "favorite")
    games = dictionaries(snapshot.get("games", []))
    stale = bool_or_false(snapshot.get("stale", False))

    if mode == "all_live":
        pages = [game_page(game, config, stale) for game in games if is_active(game)]
        if len(pages) == 0:
            pages = [no_live_page(dict_or_none(snapshot.get("nextGame")), config, stale)]
        return animation(pages, config)

    if len(games) > 0:
        return animation([game_page(game, config, stale) for game in games], config)
    next_game = dict_or_none(snapshot.get("nextGame"))
    upcoming = dictionaries(snapshot.get("upcomingGames", []))
    if next_game == None and len(upcoming) > 0:
        next_game = upcoming[0]
    return render.Root(child = no_live_page(next_game, config, stale))

def animation(pages, config):
    if len(pages) == 1:
        return render.Root(child = pages[0])
    return render.Root(
        delay = int(config.get("rotation_speed", "5")) * 1000,
        show_full_animation = True,
        child = render.Animation(children = pages),
    )

def game_page(game, config, snapshot_stale):
    game = dict_or_empty(game)
    status = text_or(game.get("status", "unknown"), "unknown")
    stale = snapshot_stale or bool_or_false(game.get("stale", False))
    scheduled = status in ["scheduled", "pregame"]
    scored = status in ["live", "intermission", "final"]
    score = str(int(number_or(game.get("awayScore", 0)))) + "-" + str(int(number_or(game.get("homeScore", 0)))) if scored else "--"
    # A 28-pixel score region fits two three-digit scores without touching logos.
    score_font = "tb-8" if len(score) <= 5 else FONT
    status_text = game_status(game, config)
    if stale:
        status_text = "STALE " + status_text
    return render.Column(children = [
        render.Row(children = [
            team_panel(dict_or_empty(game.get("awayTeam", {})), config),
            render.Box(width = 28, height = 25, child = render.Column(cross_align = "center", children = [
                render.Box(width = 28, height = 8, child = render.Text(content = "NEXT" if scheduled else ("FINAL" if status == "final" else ""), font = FONT, color = "#8e8e93")),
                render.Box(width = 28, height = 12, child = render.Text(content = "@" if scheduled else score, font = "tb-8" if scheduled else score_font, color = "#ffffff")),
                render.Box(width = 28, height = 5),
            ])),
            team_panel(dict_or_empty(game.get("homeTeam", {})), config),
        ]),
        render.Box(width = 64, height = 7, color = "#071016", child = render.Text(content = status_text[:16], font = FONT, color = "#ffcc00" if stale else ("#5de4da" if status in ["live", "intermission"] else "#d4dce4"))),
    ])

def team_panel(team, config):
    style = text_or(config.get("team_color_background_style", "dim"), "dim")
    primary = safe_color(team.get("primaryColor", "#222222"))
    background = primary if style == "full" else (primary + "55" if style == "dim" else "#000000")
    return render.Box(width = 18, height = 25, color = background, child = render.Column(children = [
        render.Box(width = 18, height = 20, child = team_mark(team, background)),
        render.Box(width = 18, height = 5, color = "#00000099", child = render.Text(content = text_or(team.get("abbreviation", "?"), "?")[:4], font = FONT, color = "#ffffff")),
    ]))


def game_status(game, config):
    game = dict_or_empty(game)
    status = text_or(game.get("status", "unknown"), "unknown")
    if status in ["scheduled", "pregame"]:
        value = text_or_empty(game.get("scheduledLocal", "")) or text_or_empty(game.get("scheduledAt", ""))
        return compact_start(value, config)
    detail = text_or_empty(game.get("statusDetail", ""))
    if status == "live":
        return text_or_empty(game.get("periodLabel", "")) + " " + text_or_empty(game.get("clock", ""))
    if status == "intermission":
        return "HALFTIME" if "HALF" in detail.upper() else "INT " + text_or_empty(game.get("periodLabel", ""))
    if status == "final":
        return detail or "FINAL"
    return {"delayed": "DELAYED", "suspended": "SUSPENDED", "postponed": "POSTPONED", "cancelled": "CANCELLED"}.get(status, "UNKNOWN")

def no_live_page(next_game, config, stale):
    next_game = dict_or_none(next_game)
    if next_game == None:
        return neutral_page("STALE" if stale else "NO GAME")
    return game_page(next_game, config, stale)



def team_mark(team, background):
    team = dict_or_empty(team)
    logo = text_or_empty(team.get("logoData", ""))
    if logo != "":
        return render.Image(src = base64.decode(logo), width = 18, height = 18)
    return render.Box(width = 18, height = 18, child = render.Text(content = text_or(team.get("abbreviation", "?"), "?")[:3], font = FONT, color = "#ffffff"))

def compact_start(value, config):
    value = text_or_empty(value)
    if value == "":
        return "TBD"
    return time.parse_time(value).in_location(config.get("$tz", "UTC")).format("Mon 3:04PM").upper()[:15]

def neutral_page(message):
    return render.Column(
        expanded = True,
        main_align = "space_around",
        cross_align = "center",
        children = [
            render.Text(content = "NBA", color = "#ffffff", font = "tb-8"),
            render.Text(content = message[:18], color = "#ff9f0a", font = FONT),
        ],
    )

def team_background(team, config):
    team = dict_or_empty(team)
    style = text_or(config.get("team_color_background_style", "dim"), "dim")
    primary = safe_color(team.get("primaryColor", "#222222"))
    if style == "full":
        return primary
    if style == "dim":
        return primary + "55"
    return "#000000"

def text_color(background):
    if background in ["#FDB927", "#FDBB30", "#FEC524", "#FFC72C", "#C4CED4"]:
        return "#000000"
    return "#ffffff"

def safe_color(value):
    value = text_or_empty(value)
    if len(value) == 7 and value[0] == "#":
        return value.upper()
    return "#222222"

def status_color(value):
    value = text_or_empty(value)
    upper = value.upper()
    if "Q" in upper or "OT" in upper or "HALF" in upper:
        return "#30d158"
    if value in ["DELAYED", "SUSPENDED", "POSTPONED", "CANCELLED"]:
        return "#ff9f0a"
    if "FINAL" in upper:
        return "#8e8e93"
    return "#ffffff"

def local_clock(value, config):
    value = text_or_empty(value)
    if value == "":
        return "TBD"
    return time.parse_time(value).in_location(config.get("$tz", "UTC")).format("3:04")

def is_active(game):
    return text_or_empty(dict_or_empty(game).get("status", "")) in ["live", "intermission"]

def provider_error(config):
    raw = text_or_empty(config.get("$provider_error", ""))
    if raw == "":
        return "DATA UNAVAILABLE"
    code = text_or_empty(dict_or_empty(json.decode(raw)).get("code", ""))
    if code == "sports_team_invalid":
        return "CHOOSE TEAM"
    return "DATA UNAVAILABLE"

def dictionaries(value):
    return [item for item in list_or_empty(value) if type(item) == "dict"]

def list_or_empty(value):
    return value if type(value) == "list" else []

def dict_or_empty(value):
    return value if type(value) == "dict" else {}

def dict_or_none(value):
    return value if type(value) == "dict" else None

def text_or_empty(value):
    return value if type(value) == "string" else ""

def text_or(value, fallback):
    value = text_or_empty(value)
    return value if value != "" else fallback

def number_or(value, fallback = 0):
    return value if type(value) in ["int", "float"] else fallback

def bool_or_false(value):
    return value if type(value) == "bool" else False

def fixture_team(team_id, abbreviation, color, with_logo = True):
    team = {"providerId": str(team_id), "abbreviation": abbreviation, "primaryColor": color}
    if with_logo:
        team["logoData"] = FIXTURE_LOGO if abbreviation in ["TOR", "BUF", "LAL"] else FIXTURE_HOME_LOGO
    return team

def fixture_game(game_id, status, period, clock, away_score = 96, home_score = 101, scheduled = "2026-10-02T00:30:00Z", stale = False, with_logos = True):
    detail = ""
    if status == "live":
        detail = period + ((" " + clock) if clock != "" else "")
    elif status == "intermission":
        detail = "HALFTIME" if period == "Q2" else "END " + period
    elif status == "final":
        detail = "FINAL" + (("/" + period) if "OT" in period else "")
    elif status in ["delayed", "postponed", "cancelled", "suspended"]:
        detail = status.upper()
    return {
        "id": "espn-site:nba:" + str(game_id),
        "awayTeam": fixture_team(13, "LAL", "#FDB927", with_logos),
        "homeTeam": fixture_team(2, "BOS", "#007A33", with_logos),
        "awayScore": away_score,
        "homeScore": home_score,
        "awayRecord": "12-8",
        "homeRecord": "15-5",
        "scheduledAt": scheduled,
        "status": status,
        "periodLabel": period,
        "clock": clock,
        "statusDetail": detail,
        "stale": stale,
    }

def fixture_snapshot(scenario):
    if scenario in ["logo_missing", "large_scores", "tied", "next_worst"]:
        game = fixture_game(99, "scheduled" if scenario == "next_worst" else "live", "P3" if "nhl" == "nba" else "Q4", "00:01", 118 if "nba" == "nba" else 24, 118 if scenario == "tied" and "nba" == "nba" else 24, with_logos = scenario != "logo_missing")
        game["awayTeam"]["abbreviation"] = "WSH"
        game["homeTeam"]["abbreviation"] = "VGK" if "nhl" == "nba" else "LAC"
        return {"games": [game]}
    variants = {
        "scheduled": [fixture_game(1, "scheduled", "", "")],
        "pregame": [fixture_game(2, "pregame", "", "")],
        "q1": [fixture_game(3, "live", "Q1", "08:42")],
        "q2": [fixture_game(4, "live", "Q2", "04:10")],
        "halftime": [fixture_game(5, "intermission", "Q2", "0:00", 50, 50)],
        "q3": [fixture_game(6, "live", "Q3", "06:30")],
        "q4": [fixture_game(7, "live", "Q4", "0:00", 96, 96)],
        "ot": [fixture_game(8, "live", "OT", "02:15", 101, 100)],
        "double_ot": [fixture_game(9, "live", "2OT", "01:02", 112, 112)],
        "final": [fixture_game(10, "final", "Q4", "", 100, 105)],
        "final_ot": [fixture_game(11, "final", "OT", "", 121, 119)],
        "delayed": [fixture_game(12, "delayed", "", "")],
        "postponed": [fixture_game(13, "postponed", "", "")],
        "cancelled": [fixture_game(14, "cancelled", "", "")],
        "suspended": [fixture_game(15, "suspended", "Q3", "")],
        "unknown": [fixture_game(16, "unknown", "", "")],
        "stale": [fixture_game(17, "live", "Q3", "08:00", stale = True)],
        "timezone_boundary": [fixture_game(18, "scheduled", "", "", scheduled = "2026-10-02T02:30:00Z")],
    }
    if scenario in variants:
        return {"games": variants[scenario], "stale": scenario == "stale"}
    if scenario == "multiple":
        return {"games": [fixture_game(20, "live", "Q2", "04:00"), fixture_game(21, "intermission", "Q2", "0:00", 55, 55), fixture_game(22, "live", "OT", "01:00", 110, 110)]}
    if scenario == "worst_case":
        return {"games": [fixture_game(23, "live", "Q4", "0:00", 999, 888, with_logos = False)]}
    if scenario in ["future", "off_day", "no_live"]:
        next_game = fixture_game(30, "scheduled", "", "", scheduled = "2026-10-03T23:30:00Z")
        return {"games": [], "nextGame": next_game, "upcomingGames": [next_game]}
    if scenario == "empty":
        return {"games": []}
    return None

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(id = "mode", name = "Mode", desc = "Follow one team or rotate through every active NBA game.", icon = "gear", default = "favorite", options = [
                schema.Option(display = "Favorite Team", value = "favorite"),
                schema.Option(display = "All Live Games", value = "all_live"),
            ]),
            schema.Dropdown(id = "teamid", name = "Favorite NBA team", desc = "Stable ESPN team identity used in Favorite Team mode.", icon = "star", default = "28", options = team_options()),
            schema.Dropdown(id = "team_color_background_style", name = "Team-colour background", desc = "Control the color behind team abbreviations and scores.", icon = "palette", default = "dim", options = [
                schema.Option(display = "Off", value = "off"),
                schema.Option(display = "Dim", value = "dim"),
                schema.Option(display = "Full", value = "full"),
            ]),
            schema.Dropdown(id = "rotation_speed", name = "Game duration", desc = "Seconds per game when more than one game is active.", icon = "gear", default = "5", options = [
                schema.Option(display = "3 seconds", value = "3"),
                schema.Option(display = "5 seconds", value = "5"),
                schema.Option(display = "8 seconds", value = "8"),
            ]),
        ],
    )

def team_options():
    return [
        schema.Option(display = "Atlanta Hawks", value = "1"),
        schema.Option(display = "Boston Celtics", value = "2"),
        schema.Option(display = "Brooklyn Nets", value = "17"),
        schema.Option(display = "Charlotte Hornets", value = "30"),
        schema.Option(display = "Chicago Bulls", value = "4"),
        schema.Option(display = "Cleveland Cavaliers", value = "5"),
        schema.Option(display = "Dallas Mavericks", value = "6"),
        schema.Option(display = "Denver Nuggets", value = "7"),
        schema.Option(display = "Detroit Pistons", value = "8"),
        schema.Option(display = "Golden State Warriors", value = "9"),
        schema.Option(display = "Houston Rockets", value = "10"),
        schema.Option(display = "Indiana Pacers", value = "11"),
        schema.Option(display = "LA Clippers", value = "12"),
        schema.Option(display = "Los Angeles Lakers", value = "13"),
        schema.Option(display = "Memphis Grizzlies", value = "29"),
        schema.Option(display = "Miami Heat", value = "14"),
        schema.Option(display = "Milwaukee Bucks", value = "15"),
        schema.Option(display = "Minnesota Timberwolves", value = "16"),
        schema.Option(display = "New Orleans Pelicans", value = "3"),
        schema.Option(display = "New York Knicks", value = "18"),
        schema.Option(display = "Oklahoma City Thunder", value = "25"),
        schema.Option(display = "Orlando Magic", value = "19"),
        schema.Option(display = "Philadelphia 76ers", value = "20"),
        schema.Option(display = "Phoenix Suns", value = "21"),
        schema.Option(display = "Portland Trail Blazers", value = "22"),
        schema.Option(display = "Sacramento Kings", value = "23"),
        schema.Option(display = "San Antonio Spurs", value = "24"),
        schema.Option(display = "Toronto Raptors", value = "28"),
        schema.Option(display = "Utah Jazz", value = "26"),
        schema.Option(display = "Washington Wizards", value = "27"),
    ]
