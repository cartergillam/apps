"""CFL Scores renders normalized sports data injected by tronbyt-server."""

load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

FONT = "CG-pixel-3x5-mono"

def main(config):
    scenario = config.get("_fixture_scenario", "")
    snapshot = fixture_snapshot(scenario)
    if snapshot == None:
        raw = config.get("$sports_data", "")
        if raw == "":
            return render.Root(child = status_page(provider_error(config), "#ff9f0a"))
        snapshot = json.decode(raw)

    selected_team = str(config.get("selectedTeam", "all"))
    mode = config.get("scoreMode", "auto")

    # Compatibility with the established Auto behavior: a numeric team means
    # Favorite Team; All Teams means the league-wide live view.
    league_mode = mode == "league" or selected_team in ["", "all"]
    games = snapshot.get("games", [])
    stale = snapshot.get("stale", False)

    if league_mode:
        pages = [game_page(game, config, stale) for game in games if is_active(game)]
        if len(pages) == 0:
            pages = [no_current_page("NO LIVE GAMES", snapshot.get("nextGame"), "", config, stale)]
        return animation(pages, config)

    if len(games) > 0:
        return animation([game_page(game, config, stale) for game in games], config)

    upcoming = snapshot.get("upcomingGames", [])
    if len(upcoming) == 0 and snapshot.get("nextGame") != None:
        upcoming = [snapshot.get("nextGame")]
    if len(upcoming) == 0:
        return render.Root(child = no_current_page("NO CURRENT GAME", None, selected_team, config, stale))
    return animation([no_current_page("NO CURRENT GAME", game, selected_team, config, stale or game.get("stale", False)) for game in upcoming], config)

def animation(pages, config):
    if len(pages) == 1:
        return render.Root(child = pages[0])
    return render.Root(
        delay = int(config.get("rotationSpeed", "5")) * 1000,
        show_full_animation = True,
        child = render.Animation(children = pages),
    )

def game_page(game, config, snapshot_stale):
    away = game.get("awayTeam", {})
    home = game.get("homeTeam", {})
    status = game.get("status", "unknown")
    stale = snapshot_stale or game.get("stale", False)
    score_visible = status in ["live", "intermission", "final"]
    away_value = str(game.get("awayScore", 0)) if score_visible else pregame_value(game.get("awayRecord", ""), config)
    home_value = str(game.get("homeScore", 0)) if score_visible else pregame_value(game.get("homeRecord", ""), config)
    return render.Column(
        expanded = True,
        children = [
            header(game_status(game, config), config, stale),
            team_row(away, away_value, config),
            team_row(home, home_value, config),
        ],
    )

def header(status, config, stale):
    display_top = config.get("displayTop", "league")
    left = "CFL"
    if stale:
        left = status
        status = "STALE"
    elif display_top == "time":
        left = local_now(config)
    elif display_top == "gameinfo":
        left = status
        status = ""
    return render.Box(
        width = 64,
        height = 8,
        color = "#000000",
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Text(content = left[:12], color = config.get("displayTimeColor", "#FFA500"), font = "tb-8"),
                render.Text(content = status[:13], color = "#ffcc00" if stale else "#ffffff", font = FONT),
            ],
        ),
    )

def team_row(team, value, config):
    background = team_background(team, config)
    text = team.get("abbreviation", "?")[:3]
    return render.Box(
        width = 64,
        height = 12,
        color = background,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Text(content = text, color = team_text_color(background), font = "tb-8"),
                render.Text(content = value[:8], color = team_text_color(background), font = "tb-8"),
            ],
        ),
    )

def no_current_page(label, game, favorite_id, config, stale):
    detail = "CHECK BACK SOON"
    if game != None:
        opponent = next_opponent(game, favorite_id)
        detail = ((opponent + " ") if opponent != "" else "") + local_start(game.get("scheduledAt", ""), config)
    return render.Column(
        expanded = True,
        main_align = "space_around",
        cross_align = "center",
        children = [
            render.Text(content = "CFL", color = config.get("displayTimeColor", "#FFA500"), font = "tb-8"),
            render.Text(content = label, color = "#ffffff", font = FONT),
            render.Text(content = (("STALE " if stale else "") + detail)[:19], color = "#ffcc00" if stale else "#8e8e93", font = FONT),
        ],
    )

def status_page(message, color):
    return render.Column(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = [
            render.Text(content = "CFL", color = "#ff9f0a", font = "tb-8"),
            render.Text(content = message[:18], color = color, font = FONT),
        ],
    )

def game_status(game, config):
    status = game.get("status", "unknown")
    if status in ["scheduled", "pregame"]:
        return ("PRE " if status == "pregame" else "") + local_start(game.get("scheduledAt", ""), config)
    detail = game.get("statusDetail", "")
    if detail != "":
        return detail
    return {
        "intermission": "HALFTIME",
        "delayed": "DELAYED",
        "suspended": "SUSPENDED",
        "postponed": "POSTPONED",
        "cancelled": "CANCELLED",
        "final": "FINAL",
    }.get(status, "STATUS UNKNOWN")

def pregame_value(record, config):
    mode = config.get("pregameDisplay", "record")
    if mode == "nothing":
        return ""

    # The old odds option is retained as a saved-value compatibility path but
    # no longer exposes provider-specific betting data; it falls back to record.
    return record[:8]

def team_background(team, config):
    display_type = config.get("displayType", "colors")
    if display_type in ["black", "retro"]:
        return "#222222"
    return safe_color(team.get("primaryColor", "#222222"))

def team_text_color(background):
    if background in ["#F15A22", "#FFB81C"]:
        return "#000000"
    return "#ffffff"

def safe_color(value):
    if len(value) == 7 and value[0] == "#":
        return value.upper()
    return "#222222"

def local_start(value, config):
    if value == "":
        return "TIME TBD"
    return time.parse_time(value).in_location(config.get("$tz", "UTC")).format("Jan 2 3:04P")

def local_now(config):
    fixture_now = config.get("_fixture_now", "")
    now = time.now() if fixture_now == "" else time.parse_time(fixture_now)
    return now.in_location(config.get("$tz", "UTC")).format("3:04")

def next_opponent(game, favorite_id):
    away = game.get("awayTeam", {})
    home = game.get("homeTeam", {})
    if str(away.get("providerId", "")) == favorite_id:
        return "@" + home.get("abbreviation", "?")[:3]
    if str(home.get("providerId", "")) == favorite_id:
        return "vs " + away.get("abbreviation", "?")[:3]
    return away.get("abbreviation", "?")[:3] + "@" + home.get("abbreviation", "?")[:3]

def is_active(game):
    return game.get("status", "") in ["live", "intermission"]

def provider_error(config):
    raw = config.get("$provider_error", "")
    if raw == "":
        return "DATA UNAVAILABLE"
    code = json.decode(raw).get("code", "")
    if code == "sports_team_invalid":
        return "CHOOSE TEAM"
    return "DATA UNAVAILABLE"

def fixture_team(team_id, abbreviation, color):
    return {"providerId": str(team_id), "abbreviation": abbreviation, "primaryColor": color}

def fixture_game(game_id, status, period, clock, away_score = 17, home_score = 21, scheduled = "2026-08-06T23:00:00Z", stale = False):
    detail = ""
    if status == "live":
        detail = period + (" " + clock if clock != "" else "")
    elif status == "intermission":
        detail = "HALFTIME"
    elif status == "final":
        detail = "FINAL" + ("/OT" if period == "OT" else "")
    return {
        "id": "espn-site:cfl:" + str(game_id),
        "awayTeam": fixture_team(86, "WPG", "#1D3D7A"),
        "homeTeam": fixture_team(85, "TOR", "#051C3E"),
        "awayScore": away_score,
        "homeScore": home_score,
        "awayRecord": "4-3",
        "homeRecord": "5-2",
        "scheduledAt": scheduled,
        "status": status,
        "periodLabel": period,
        "clock": clock,
        "statusDetail": detail,
        "stale": stale,
    }

def fixture_snapshot(scenario):
    variants = {
        "scheduled": [fixture_game(1, "scheduled", "", "")],
        "pregame": [fixture_game(2, "pregame", "", "")],
        "q1": [fixture_game(3, "live", "Q1", "12:34")],
        "q2": [fixture_game(4, "live", "Q2", "08:42")],
        "q3": [fixture_game(5, "live", "Q3", "05:11")],
        "q4": [fixture_game(6, "live", "Q4", "01:02")],
        "halftime": [fixture_game(7, "intermission", "Q2", "0:00", 10, 10)],
        "overtime": [fixture_game(8, "live", "OT", "", 24, 24)],
        "final": [fixture_game(9, "final", "Q4", "", 24, 31)],
        "final_ot": [fixture_game(10, "final", "OT", "", 27, 30)],
        "delayed": [fixture_game(11, "delayed", "", "")],
        "postponed": [fixture_game(12, "postponed", "", "")],
        "cancelled": [fixture_game(13, "cancelled", "", "")],
        "suspended": [fixture_game(14, "suspended", "Q3", "")],
        "stale": [fixture_game(15, "live", "Q3", "08:00", stale = True)],
        "timezone_boundary": [fixture_game(16, "scheduled", "", "", scheduled = "2026-08-07T02:00:00Z")],
    }
    if scenario in variants:
        return {"games": variants[scenario], "stale": scenario == "stale"}
    if scenario == "multiple":
        return {"games": [fixture_game(20, "live", "Q2", "04:00"), fixture_game(21, "intermission", "Q2", "0:00", 14, 14)]}
    if scenario in ["future", "off_day"]:
        next_game = fixture_game(30, "scheduled", "", "", scheduled = "2026-08-08T23:00:00Z")
        return {"games": [], "nextGame": next_game, "upcomingGames": [next_game]}
    if scenario == "no_live":
        return {"games": [], "nextGame": fixture_game(31, "scheduled", "", "", scheduled = "2026-08-08T23:00:00Z")}
    if scenario == "empty":
        return {"games": []}
    return None

teamOptions = [
    schema.Option(display = "All Teams", value = "all"),
    schema.Option(display = "BC Lions", value = "79"),
    schema.Option(display = "Calgary Stampeders", value = "80"),
    schema.Option(display = "Edmonton Elks", value = "81"),
    schema.Option(display = "Hamilton Tiger-Cats", value = "82"),
    schema.Option(display = "Montréal Alouettes", value = "83"),
    schema.Option(display = "Ottawa Redblacks", value = "87"),
    schema.Option(display = "Saskatchewan Roughriders", value = "84"),
    schema.Option(display = "Toronto Argonauts", value = "85"),
    schema.Option(display = "Winnipeg Blue Bombers", value = "86"),
]

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(id = "selectedTeam", name = "Favourite team", desc = "Stable ESPN team ID; All Teams selects the league view.", icon = "gear", default = "all", options = teamOptions),
            schema.Dropdown(id = "scoreMode", name = "Display mode", desc = "Auto follows a numeric favorite, otherwise shows all live CFL games.", icon = "gear", default = "auto", options = [
                schema.Option(display = "Auto", value = "auto"),
                schema.Option(display = "Favourite team only", value = "favorite"),
                schema.Option(display = "League / all live games", value = "league"),
            ]),
            schema.Dropdown(id = "upcomingGames", name = "Upcoming games", desc = "Future favorite-team games shown when there is no current game.", icon = "gear", default = "1", options = [
                schema.Option(display = "1 game", value = "1"),
                schema.Option(display = "2 games", value = "2"),
                schema.Option(display = "3 games", value = "3"),
            ]),
            schema.Dropdown(id = "rotationSpeed", name = "Rotation speed", desc = "Seconds per game.", icon = "gear", default = "5", options = [
                schema.Option(display = "3 seconds", value = "3"),
                schema.Option(display = "5 seconds", value = "5"),
                schema.Option(display = "8 seconds", value = "8"),
                schema.Option(display = "10 seconds", value = "10"),
                schema.Option(display = "15 seconds", value = "15"),
            ]),
            schema.Dropdown(id = "displayType", name = "Display type", desc = "Team colors or a neutral high-contrast style.", icon = "gear", default = "colors", options = [
                schema.Option(display = "Team colors", value = "colors"),
                schema.Option(display = "Black", value = "black"),
                schema.Option(display = "Retro", value = "retro"),
            ]),
            schema.Dropdown(id = "pregameDisplay", name = "Pre-game", desc = "Show team records or leave the value area blank.", icon = "gear", default = "record", options = [
                schema.Option(display = "Team record", value = "record"),
                schema.Option(display = "Nothing", value = "nothing"),
            ]),
            schema.Dropdown(id = "displayTop", name = "Top display", desc = "League, device-local time, or game information.", icon = "gear", default = "league", options = [
                schema.Option(display = "League name", value = "league"),
                schema.Option(display = "Current time", value = "time"),
                schema.Option(display = "Game info only", value = "gameinfo"),
            ]),
            schema.Dropdown(id = "displayTimeColor", name = "Top display color", desc = "Header accent color.", icon = "gear", default = "#FFA500", options = [
                schema.Option(display = "White", value = "#FFF"),
                schema.Option(display = "Yellow", value = "#FF0"),
                schema.Option(display = "Red", value = "#F00"),
                schema.Option(display = "Blue", value = "#00F"),
                schema.Option(display = "Green", value = "#0F0"),
                schema.Option(display = "Orange", value = "#FFA500"),
            ]),
        ],
    )
