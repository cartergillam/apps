"""NFL Live renders normalized sports data injected by tronbyt-server."""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

FONT = "CG-pixel-3x5-mono"
FIXTURE_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAC9UlEQVR4nMyUXUhkZRjH/+85Z47nzJlPR2d2110s2AzWrSGKsQ+WFots6yLQymWpi2WXIegDiRZapG268aKb2BaiyOomsAj6MDUQY0iFQk3J1PFr/Bh11HFmnHE8c+Z8zLwxSlKEZOSCz825OM/zex6e9/e+DA45jj6Q+y/JlFLX0FjsQnAw8tLwZPwui5kz6h6q/PS5uqq3/swhBwSduPn5cFNnf+RSaCFVsRpXkFc1gAInT5UicPW+m1cazr4HIPKvwOlw8uK19/tvdQ/EypQtGWDo38cwKOxlVtzhFvT62tPd+wJ/GNk4/2XH2NvBoej5xfDm7nI4BmAZsCwDgSMQOcBCCnBIPDZ1gtMn7bu9KKXFbxkAK+SUZWp0/fIn30w0RcIJOPIyPIyOUl2BS8vCqcpw5GQ4VBlWLQeLnoP0YQC1bes4buPWdg5Faf2qJdfW9UohI7NUVsRjWRXXU2kIhgrOMHa6Ut4ETRSxbbEhYXUganHiZ9GJGdaC8nENkeUt1DdWdxEaXnwkefGNfmFwHIZQgrxVRNZWLHLuFC1LTszxNswWRCxRHut5Dhs5im1ZB9QCgAJAWDTW3bnwxbsX7ue0hegVznt3L/O4b1h4+AH71e/XLg+uKGAkM3izgHRGKa5N8dgFshJNC0uRJMCz8FW74XII6eCvMfsTNcfj/oaz1wkhSUIpFQkhCqXU83xzT/vETMJ3wiXhTKVVa3rRe81sMgXdbsnZ8vHA163fTbuSqW14q8ohCRxuvfnoZ98Gw+deu3RvPc/zv+95qGla9dOvdvxUwpe4MrKOUhsbCfgffMF7pryv+D8Wk59s75trSKRzNb0j8XuoodLKCmvwg+ba5qJZxcn2xC7a7w/82JnMaDWnjtmQVXJ9H914rJEQsvoXsU2EEH1sKv5yaD6xfM5XMetxSpOEkPw/fPtlNPrMs693GL+FNm743+lJqiqtOsjt2Tfm5zcdo6FYC6VUkGX1qf8Fux1x9N/DQwf+EQAA//9L8zoehhHCsgAAAABJRU5ErkJggg=="
FIXTURE_HOME_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAACDklEQVR4nOyT3UtTfxzH35/z8Bv+OtNtnjZdGkPpwQsfSmNtLJdlygiKddFF0E1Bd13VRX+ABA289aIguozydkjQlAJrM6OGmjXInNtsY415fOrs7GzfWFR0MQnJi6Be8L35Xrzg8/583hx2mH/C30eo9skYs0BROtXxF26aiR1Z+E88MJTONRY2VYnnORJFUbXJdZn2tpZpX2/PqM0mPyIihTEmEFMUC1TVVJhPtJYW4s5ybNGlv1/qLGfzdgMvkFBnRHr/XlzNruDZ1Cxy6SzA8QDHoUb6H44mK7rb9y02yObEOZ9HFRgooL2cd+kzsYZyOlcWrfWy5B8EDCKwtg41+hbmj1nsMUpocdhR1HWsrm18nUTTNFz0n8SHZMZxd/Sxo99z6LZAtcYrBp9XMvi8lfFVAM7S0vJAKRKt0/Mrmug/NZAkvs0afo3mQhGbG58xVxFqRfCSiLyyDuOuGni6D6qDfc4RgYjKAFZ/inDi2/ueZ1PqefSsWiicj6cyvXPv4kCphP4TPUgsf8LwnYewmE24dePSBBFFaTsbZIx5AyP3bz4IPnW7ulrRaLOA43jsttS/unzh9BkiSlbd8lYQ0RPG2LE+V0cgGApfa7bLeBNL4ejhjumKbMuz+YW0EtH1ychsPjQ5NSSbavXj7q7h7XqqMjYeuTcWCgcZYztekB/8+V3+C4VfAgAA///IP8X2TpTSQQAAAABJRU5ErkJggg=="

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
            render.Text(content = "NFL", color = "#ffffff", font = "tb-8"),
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
    if background in ["#FFB612", "#FFB81C", "#FFC20E", "#FFC62F", "#D3BC8D", "#B0B7BC"]:
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

def fixture_game(game_id, status, period, clock, away_score = 17, home_score = 21, scheduled = "2026-09-11T00:20:00Z", stale = False, tie = False, with_logos = True):
    detail = ""
    if status == "live":
        detail = period + ((" " + clock) if clock != "" else "")
    elif status == "intermission":
        detail = "HALFTIME" if period == "Q2" else "END " + period
    elif status == "final":
        detail = "FINAL/TIE" if tie else "FINAL" + (("/OT") if period == "OT" else "")
    elif status in ["delayed", "postponed", "cancelled", "suspended"]:
        detail = status.upper()
    return {
        "id": "espn-site:nfl:" + str(game_id),
        "awayTeam": fixture_team(2, "BUF", "#00338D", with_logos),
        "homeTeam": fixture_team(17, "NE", "#002244", with_logos),
        "awayScore": away_score,
        "homeScore": home_score,
        "awayRecord": "8-3",
        "homeRecord": "6-5",
        "scheduledAt": scheduled,
        "status": status,
        "periodLabel": period,
        "clock": clock,
        "statusDetail": detail,
        "tie": tie,
        "stale": stale,
    }

def fixture_snapshot(scenario):
    if scenario in ["logo_missing", "large_scores", "tied", "next_worst"]:
        game = fixture_game(99, "scheduled" if scenario == "next_worst" else "live", "P3" if "nhl" == "nfl" else "Q4", "00:01", 118 if "nba" == "nfl" else 24, 118 if scenario == "tied" and "nba" == "nfl" else 24, with_logos = scenario != "logo_missing")
        game["awayTeam"]["abbreviation"] = "WSH"
        game["homeTeam"]["abbreviation"] = "VGK" if "nhl" == "nfl" else "LAC"
        return {"games": [game]}
    variants = {
        "scheduled": [fixture_game(1, "scheduled", "", "")],
        "pregame": [fixture_game(2, "pregame", "", "")],
        "q1": [fixture_game(3, "live", "Q1", "08:42")],
        "q2": [fixture_game(4, "live", "Q2", "04:10")],
        "halftime": [fixture_game(5, "intermission", "Q2", "0:00", 14, 10)],
        "q3": [fixture_game(6, "live", "Q3", "06:30")],
        "q4": [fixture_game(7, "live", "Q4", "01:02")],
        "zero_clock": [fixture_game(8, "live", "Q4", "0:00", 24, 24)],
        "quarter_break": [fixture_game(9, "intermission", "Q3", "0:00", 17, 17)],
        "ot": [fixture_game(10, "live", "OT", "02:15", 24, 24)],
        "final": [fixture_game(11, "final", "Q4", "", 24, 17)],
        "final_ot": [fixture_game(12, "final", "OT", "", 27, 24)],
        "tie": [fixture_game(13, "final", "OT", "", 20, 20, tie = True)],
        "delayed": [fixture_game(14, "delayed", "", "")],
        "postponed": [fixture_game(15, "postponed", "", "")],
        "cancelled": [fixture_game(16, "cancelled", "", "")],
        "suspended": [fixture_game(17, "suspended", "Q3", "")],
        "unknown": [fixture_game(18, "unknown", "", "")],
        "stale": [fixture_game(19, "live", "Q3", "08:00", stale = True)],
        "timezone_boundary": [fixture_game(20, "scheduled", "", "", scheduled = "2026-09-11T02:30:00Z")],
    }
    if scenario in variants:
        return {"games": variants[scenario], "stale": scenario == "stale"}
    if scenario == "multiple":
        return {"games": [fixture_game(21, "live", "Q2", "04:00"), fixture_game(22, "intermission", "Q2", "0:00", 14, 14), fixture_game(23, "live", "OT", "01:00", 24, 24)]}
    if scenario == "worst_case":
        return {"games": [fixture_game(24, "live", "Q4", "0:00", 999, 888, with_logos = False)]}
    if scenario in ["future", "off_day", "no_live"]:
        next_game = fixture_game(30, "scheduled", "", "", scheduled = "2026-09-13T17:00:00Z")
        return {"games": [], "nextGame": next_game, "upcomingGames": [next_game]}
    if scenario == "empty":
        return {"games": []}
    return None

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(id = "mode", name = "Mode", desc = "Follow one team or rotate through every active NFL game.", icon = "gear", default = "favorite", options = [
                schema.Option(display = "Favorite Team", value = "favorite"),
                schema.Option(display = "All Live Games", value = "all_live"),
            ]),
            schema.Dropdown(id = "teamid", name = "Favorite NFL team", desc = "Stable ESPN team identity used in Favorite Team mode.", icon = "star", default = "2", options = team_options()),
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
        schema.Option(display = "Arizona Cardinals", value = "22"),
        schema.Option(display = "Atlanta Falcons", value = "1"),
        schema.Option(display = "Baltimore Ravens", value = "33"),
        schema.Option(display = "Buffalo Bills", value = "2"),
        schema.Option(display = "Carolina Panthers", value = "29"),
        schema.Option(display = "Chicago Bears", value = "3"),
        schema.Option(display = "Cincinnati Bengals", value = "4"),
        schema.Option(display = "Cleveland Browns", value = "5"),
        schema.Option(display = "Dallas Cowboys", value = "6"),
        schema.Option(display = "Denver Broncos", value = "7"),
        schema.Option(display = "Detroit Lions", value = "8"),
        schema.Option(display = "Green Bay Packers", value = "9"),
        schema.Option(display = "Houston Texans", value = "34"),
        schema.Option(display = "Indianapolis Colts", value = "11"),
        schema.Option(display = "Jacksonville Jaguars", value = "30"),
        schema.Option(display = "Kansas City Chiefs", value = "12"),
        schema.Option(display = "Las Vegas Raiders", value = "13"),
        schema.Option(display = "Los Angeles Chargers", value = "24"),
        schema.Option(display = "Los Angeles Rams", value = "14"),
        schema.Option(display = "Miami Dolphins", value = "15"),
        schema.Option(display = "Minnesota Vikings", value = "16"),
        schema.Option(display = "New England Patriots", value = "17"),
        schema.Option(display = "New Orleans Saints", value = "18"),
        schema.Option(display = "New York Giants", value = "19"),
        schema.Option(display = "New York Jets", value = "20"),
        schema.Option(display = "Philadelphia Eagles", value = "21"),
        schema.Option(display = "Pittsburgh Steelers", value = "23"),
        schema.Option(display = "San Francisco 49ers", value = "25"),
        schema.Option(display = "Seattle Seahawks", value = "26"),
        schema.Option(display = "Tampa Bay Buccaneers", value = "27"),
        schema.Option(display = "Tennessee Titans", value = "10"),
        schema.Option(display = "Washington Commanders", value = "28"),
    ]
