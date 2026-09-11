"""NBA Live renders normalized sports data injected by tronbyt-server."""

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
            return render.Root(child = neutral_page(provider_error(config)))
        snapshot = json.decode(raw)

    mode = config.get("mode", "favorite")
    team_id = str(config.get("teamid", "28"))
    games = snapshot.get("games", [])
    stale = snapshot.get("stale", False)

    if mode == "all_live":
        pages = [game_page(game, config, stale) for game in games if is_active(game)]
        if len(pages) == 0:
            pages = [no_live_page("NO LIVE GAMES", snapshot.get("nextGame"), "", config, stale)]
        return animation(pages, config)

    if len(games) > 0:
        return animation([game_page(game, config, stale) for game in games], config)
    next_game = snapshot.get("nextGame")
    if next_game == None and len(snapshot.get("upcomingGames", [])) > 0:
        next_game = snapshot.get("upcomingGames", [])[0]
    return render.Root(child = no_live_page("NO LIVE GAME", next_game, team_id, config, stale))

def animation(pages, config):
    if len(pages) == 1:
        return render.Root(child = pages[0])
    return render.Root(
        delay = int(config.get("rotation_speed", "5")) * 1000,
        show_full_animation = True,
        child = render.Animation(children = pages),
    )

def game_page(game, config, snapshot_stale):
    status = game.get("status", "unknown")
    stale = snapshot_stale or game.get("stale", False)
    score_visible = status in ["live", "intermission", "final"]
    away_value = str(game.get("awayScore", 0)) if score_visible else game.get("awayRecord", "")
    home_value = str(game.get("homeScore", 0)) if score_visible else game.get("homeRecord", "")
    return render.Column(
        expanded = True,
        children = [
            header(game_status(game, config), stale),
            team_row("A", game.get("awayTeam", {}), away_value, config),
            team_row("H", game.get("homeTeam", {}), home_value, config),
        ],
    )

def header(status, stale):
    return render.Box(
        width = 64,
        height = 8,
        color = "#000000",
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Text(content = "STALE" if stale else "NBA", color = "#ffcc00" if stale else "#8e8e93", font = FONT),
                render.Text(content = status[:15], color = status_color(status), font = FONT),
            ],
        ),
    )

def team_row(side, team, value, config):
    background = team_background(team, config)
    return render.Box(
        width = 64,
        height = 12,
        color = background,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [
                render.Text(content = side, color = "#8e8e93", font = FONT),
                render.Text(content = team.get("abbreviation", "?")[:3], color = text_color(background), font = "tb-8"),
                render.Text(content = str(value)[:7], color = text_color(background), font = "tb-8"),
            ],
        ),
    )

def game_status(game, config):
    status = game.get("status", "unknown")
    if status in ["scheduled", "pregame"]:
        prefix = "PRE " if status == "pregame" else ""
        return prefix + local_start(game.get("scheduledLocal", game.get("scheduledAt", "")), config)
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

def no_live_page(label, next_game, favorite_id, config, stale):
    secondary = "CHECK BACK SOON"
    if next_game != None:
        opponent = next_opponent(next_game, favorite_id)
        secondary = ((opponent + " ") if opponent != "" else "") + local_start(next_game.get("scheduledLocal", next_game.get("scheduledAt", "")), config)
    return render.Column(
        expanded = True,
        main_align = "space_around",
        cross_align = "center",
        children = [
            render.Text(content = "NBA", color = "#ffffff", font = "tb-8"),
            render.Text(content = label, color = "#8e8e93", font = FONT),
            render.Text(content = (("STALE " if stale else "") + secondary)[:20], color = "#ffcc00" if stale else "#ffffff", font = FONT),
        ],
    )

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
    style = config.get("team_color_background_style", "dim")
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
    if len(value) == 7 and value[0] == "#":
        return value.upper()
    return "#222222"

def status_color(value):
    upper = value.upper()
    if "Q" in upper or "OT" in upper or "HALF" in upper:
        return "#30d158"
    if value in ["DELAYED", "SUSPENDED", "POSTPONED", "CANCELLED"]:
        return "#ff9f0a"
    if "FINAL" in upper:
        return "#8e8e93"
    return "#ffffff"

def local_start(value, config):
    if value == "":
        return "TIME TBD"
    local = time.parse_time(value).in_location(config.get("$tz", "UTC"))
    fixture_now = config.get("_fixture_now", "")
    now = time.now() if fixture_now == "" else time.parse_time(fixture_now)
    if local.format("2006-01-02") == now.in_location(config.get("$tz", "UTC")).format("2006-01-02"):
        return local.format("3:04P")
    return local.format("Jan 2 3:04P").upper()

def next_opponent(game, favorite_id):
    away = game.get("awayTeam", {})
    home = game.get("homeTeam", {})
    if str(away.get("providerId", "")) == favorite_id:
        return "@" + home.get("abbreviation", "?")[:3]
    if str(home.get("providerId", "")) == favorite_id:
        return "VS " + away.get("abbreviation", "?")[:3]
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

def fixture_game(game_id, status, period, clock, away_score = 96, home_score = 101, scheduled = "2026-10-02T00:30:00Z", stale = False):
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
        "awayTeam": fixture_team(28, "TOR", "#CE1141"),
        "homeTeam": fixture_team(2, "BOS", "#007A33"),
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
