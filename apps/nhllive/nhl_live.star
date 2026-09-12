"""NHL Live renders normalized sports data injected by tronbyt-server."""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

FONT = "CG-pixel-3x5-mono"
FIXTURE_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAAAl0lEQVR4nGL5//8/A3Fg6uI9OZVzGJiZGZgYISJMROpkYGDIjnWpzA9i+PWbAWLd33+MxNsMAS4x7Xv3XmBgYZKWFmH4TyI4d+UBk1IMm2r83qNXWUiyloGBwVBbPsDNxNxAxclKi2RnMzAwvHzzUUSQl5mZiRzNcEBCaI9qHgKa//3DnhaI0vz9xy+saWkkpjBAAAAA//8G7WGWVWaStAAAAABJRU5ErkJggg=="
FIXTURE_HOME_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAADsUlEQVR4nKSUYUyVZRTHf/e93ItXTbaQyRYguCkBwQaTFWG1ufkhYCsimC0z/VCDCbXaFLemrj4w64NuZVajNjawWmuzK4ZzLbFNMoQtrqRMHOoFltN7Abl2uVze572nPe+9Ihr4pbO92/Oe53/+z3n+5zkniaVtE/ASUAqsSfhuAX2AFzi3WJBjEV858BHwfFpaWlJ+fkEsa8UNQ2/4w9mxocuXjEAgoIDfgANAzyOSohmw8vILpKPj2Ozk1B1TRCwZfF1kcJvo9eTklNne3j6bl5cvGgvsWYpsPyANdQUqGp7QRPfNt1XE99oDrtnwtFlfm68z1cT7Hr5yFdDZtHOL+enOcZcl6XRfdqGU4HA4IHzVBlmedWSmp1BYtR/8HXDrJ5racswjbb+4gEqgS+OWAb6SkhJRligJeuXvb9Nlucs++T+fx4UcP7BG5NcckdteHWMWFxfrvYEEF1s1sLOzMzJ/n8AJeb8mxSbYUuKRTxrWysH6HGl8OdX2rUpGxk5vm4d7vd5I4sA6TfhDZmaWhCNzC3SbkW/2rreDD+3KEJFLIhIR8bdI3hPxTIdOvDmPDs9EzYyMTO3/Xr/DwoIns2PLXUEnERMcBjgmUaaydRu6FuJCWyOmLGNk5Dr+ADy+AlYmzYC6CabJcrfLWZCbHRsfHyvShKtSZdDi3HMu5mLxEiU7QN2xl62nQrSe6n7gOXy4PYUMTy90l8cdbsORKhM6g1WaMPJPUq5B8UGIJjI0QuB9F5ii6mkPleVrEAxGxkIc+jHI113T7KjdxOrS3aBMcLu4m9TshF6tJV0bcvPE1BW+/8qktTmu4eElNdwxj55TotZvyNX+kzrDk8NXhl7s6z2vysrKnPYVZocIBKft5cDwNGe+aESxjFH/dW4EQAe5F0yBvt7f1dXhKzr2Z/2fBoxWVlYqu83CF+X28SJJ8Sz+DvXXsj1ZpPspkbsX7XasqKjQ+vmB1Hud0gAcPfLxe9Fdm3uSwzcDfHnawZwZi3eKCtkg5VhJ7trHqH1rH4x9B9Yon519IfrO3sPJQD3w1cLidRggR/cUmaLGLJGwiEyIyJSI7xUR36vxtYQSyk1bn+8uNI141u2LDQd3fMOQ6po6NeAbjNoSaNPT5q837tXAGhj4M1pdXaM0FjgGuB4eDgvtbeADp9OZtXFjqTxT9uzcOuOMXYJrsc3qj/M97v7+fodlWVqzFuACMJgYZUvaaqAJOAsEgVgiIJjw6b3UBNZ4FNH/tn8DAAD//zFWPu055LSqAAAAAElFTkSuQmCC"

def main(config):
    scenario = config.get("_fixture_scenario", "")
    snapshot = fixture_snapshot(scenario)
    if snapshot == None:
        raw = config.get("$provider_data", "")
        if raw == "":
            return render.Root(child = neutral_page(provider_error(config)))
        snapshot = json.decode(raw)

    snapshot = dict_or_empty(snapshot)

    mode = text_or(config.get("mode", "favorite"), "favorite")
    team_id = text_or(config.get("teamid", "10"), "10")

    # Compatibility: historical teamid=0 selected a random league team.
    # The deterministic successor is the All Live Games mode.
    if team_id == "0":
        mode = "all_live"

    games = dictionaries(snapshot.get("games", []))
    stale = bool_or_false(snapshot.get("stale", False))
    if mode == "all_live":
        pages = [game_page(game, config, stale) for game in games if is_live(game)]
        if len(pages) == 0:
            pages = [no_live_page(dict_or_none(snapshot.get("nextGame")), config, stale)]
        return animation(pages, config)

    if len(games) == 0:
        if config.bool("gameday", False):
            return []
        return render.Root(child = no_live_page(dict_or_none(snapshot.get("nextGame")), config, stale))
    return animation([game_page(game, config, stale) for game in games], config)

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
    status_text = display_status(game, config)
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
            render.Text(content = "NHL", color = "#ffffff", font = "tb-8"),
            render.Text(content = message[:18], color = "#ff9f0a", font = FONT),
        ],
    )

def display_status(game, config):
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

def local_clock(value, config):
    value = text_or_empty(value)
    if value == "":
        return "TBD"
    return time.parse_time(value).in_location(config.get("$tz", "UTC")).format("3:04")

def is_live(game):
    return text_or_empty(dict_or_empty(game).get("status", "")) in ["live", "intermission"]

def status_badge(status):
    return {
        "scheduled": "NEXT",
        "pregame": "PRE",
        "live": "LIVE",
        "intermission": "INT",
        "delayed": "DELAY",
        "suspended": "SUSP",
        "postponed": "PPD",
        "cancelled": "CANCEL",
        "final": "FINAL",
    }.get(status, "NHL")

def status_color(status):
    status = text_or_empty(status)
    if status in ["live", "intermission"]:
        return "#30d158"
    if status in ["delayed", "suspended", "postponed", "cancelled"]:
        return "#ff9f0a"
    if status == "final":
        return "#8e8e93"
    return "#ffffff"

def safe_color(value):
    value = text_or_empty(value)
    if len(value) == 7 and value[0] == "#":
        return value
    return "#222222"

def dim_color(value):
    # Pixlet accepts #RRGGBBAA. Preserve team identity at low intensity so
    # white score text remains readable on a physical matrix.
    return value + "55"

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

def fixture_game(game_id, status, period, clock, away_score = 1, home_score = 2, scheduled = "2026-01-10T00:30:00Z", stale = False, with_logos = True):
    detail = ""
    if status == "live":
        detail = period + (" " + clock if clock != "" else "")
    elif status == "intermission":
        detail = "INT " + period
    elif status == "final":
        detail = "FINAL" + ("/" + period if period in ["OT", "SO"] else "")
    return {
        "id": "nhl:" + str(game_id),
        "awayTeam": fixture_team(10, "TOR", "#003E7E", with_logos),
        "homeTeam": fixture_team(6, "BOS", "#FFB81C", with_logos),
        "awayScore": away_score,
        "homeScore": home_score,
        "scheduledAt": scheduled,
        "status": status,
        "periodLabel": period,
        "clock": clock,
        "statusDetail": detail,
        "stale": stale,
    }

def fixture_snapshot(scenario):
    if scenario in ["logo_missing", "large_scores", "tied", "next_worst"]:
        game = fixture_game(99, "scheduled" if scenario == "next_worst" else "live", "P3" if "nhl" == "nhl" else "Q4", "00:01", 118 if "nba" == "nhl" else 24, 118 if scenario == "tied" and "nba" == "nhl" else 24, with_logos = scenario != "logo_missing")
        game["awayTeam"]["abbreviation"] = "WSH"
        game["homeTeam"]["abbreviation"] = "VGK" if "nhl" == "nhl" else "LAC"
        return {"games": [game]}
    statuses = {
        "scheduled": [fixture_game(1, "scheduled", "", "")],
        "pregame": [fixture_game(2, "pregame", "", "")],
        "live_p1": [fixture_game(3, "live", "P1", "12:34")],
        "live_p2": [fixture_game(4, "live", "P2", "09:10", 2, 2)],
        "live_p3": [fixture_game(5, "live", "P3", "01:00", 3, 2)],
        "intermission": [fixture_game(6, "intermission", "P2", "00:00", 1, 1)],
        "overtime": [fixture_game(7, "live", "OT", "03:21", 2, 2)],
        "shootout": [fixture_game(8, "live", "SO", "", 3, 3)],
        "final": [fixture_game(9, "final", "", "", 1, 4)],
        "final_ot": [fixture_game(10, "final", "OT", "", 4, 3)],
        "final_so": [fixture_game(11, "final", "SO", "", 2, 3)],
        "delayed": [fixture_game(12, "delayed", "", "")],
        "postponed": [fixture_game(13, "postponed", "", "")],
        "suspended": [fixture_game(14, "suspended", "", "")],
        "cancelled": [fixture_game(15, "cancelled", "", "")],
        "stale": [fixture_game(16, "live", "P2", "08:00", 2, 1, stale = True)],
        "timezone_boundary": [fixture_game(17, "scheduled", "", "", scheduled = "2026-01-10T02:30:00Z")],
    }
    if scenario in statuses:
        return {"games": statuses[scenario], "stale": scenario == "stale"}
    if scenario == "multiple":
        return {"games": [fixture_game(20, "live", "P1", "11:00"), fixture_game(21, "intermission", "P2", "00:00", 3, 3)]}
    if scenario == "worst_case":
        return {"games": [fixture_game(22, "live", "P3", "00:00", 999, 888, with_logos = False)]}
    if scenario in ["no_live", "future"]:
        return {"games": [], "nextGame": fixture_game(30, "scheduled", "", "", scheduled = "2026-01-11T00:30:00Z")}
    if scenario == "no_games":
        return {"games": []}
    return None

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(id = "mode", name = "Mode", desc = "Follow one team or rotate through every live NHL game.", icon = "gear", default = "favorite", options = [
                schema.Option(display = "Favorite Team", value = "favorite"),
                schema.Option(display = "All Live Games", value = "all_live"),
            ]),
            schema.Dropdown(id = "teamid", name = "Favorite NHL team", desc = "Stable NHL team identity. Used in Favorite Team mode.", icon = "star", default = "10", options = team_options()),
            schema.Dropdown(id = "team_color_background_style", name = "Team-colour background", desc = "Control the color behind team abbreviations.", icon = "palette", default = "dim", options = [
                schema.Option(display = "Off", value = "off"),
                schema.Option(display = "Dim", value = "dim"),
                schema.Option(display = "Full", value = "full"),
            ]),
            schema.Dropdown(id = "rotation_speed", name = "Game duration", desc = "Seconds per game when more than one game is shown.", icon = "gear", default = "5", options = [
                schema.Option(display = "3 seconds", value = "3"),
                schema.Option(display = "5 seconds", value = "5"),
                schema.Option(display = "8 seconds", value = "8"),
            ]),
            schema.Toggle(id = "gameday", name = "Game day only", desc = "Hide Favorite Team mode on days without a selected-team game.", icon = "calendar", default = False),
        ],
    )

def team_options():
    return [
        schema.Option(display = "Anaheim Ducks", value = "24"),
        schema.Option(display = "Boston Bruins", value = "6"),
        schema.Option(display = "Buffalo Sabres", value = "7"),
        schema.Option(display = "Calgary Flames", value = "20"),
        schema.Option(display = "Carolina Hurricanes", value = "12"),
        schema.Option(display = "Chicago Blackhawks", value = "16"),
        schema.Option(display = "Colorado Avalanche", value = "21"),
        schema.Option(display = "Columbus Blue Jackets", value = "29"),
        schema.Option(display = "Dallas Stars", value = "25"),
        schema.Option(display = "Detroit Red Wings", value = "17"),
        schema.Option(display = "Edmonton Oilers", value = "22"),
        schema.Option(display = "Florida Panthers", value = "13"),
        schema.Option(display = "Los Angeles Kings", value = "26"),
        schema.Option(display = "Minnesota Wild", value = "30"),
        schema.Option(display = "Montréal Canadiens", value = "8"),
        schema.Option(display = "Nashville Predators", value = "18"),
        schema.Option(display = "New Jersey Devils", value = "1"),
        schema.Option(display = "New York Islanders", value = "2"),
        schema.Option(display = "New York Rangers", value = "3"),
        schema.Option(display = "Ottawa Senators", value = "9"),
        schema.Option(display = "Philadelphia Flyers", value = "4"),
        schema.Option(display = "Pittsburgh Penguins", value = "5"),
        schema.Option(display = "San Jose Sharks", value = "28"),
        schema.Option(display = "Seattle Kraken", value = "55"),
        schema.Option(display = "St. Louis Blues", value = "19"),
        schema.Option(display = "Tampa Bay Lightning", value = "14"),
        schema.Option(display = "Toronto Maple Leafs", value = "10"),
        schema.Option(display = "Utah Mammoth", value = "68"),
        schema.Option(display = "Vancouver Canucks", value = "23"),
        schema.Option(display = "Vegas Golden Knights", value = "54"),
        schema.Option(display = "Washington Capitals", value = "15"),
        schema.Option(display = "Winnipeg Jets", value = "52"),
    ]
