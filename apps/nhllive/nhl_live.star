"""NHL Live renders normalized sports data injected by tronbyt-server."""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

FONT = "CG-pixel-3x5-mono"
FIXTURE_LOGO = "iVBORw0KGgoAAAANSUhEUgAAABAAAAATCAYAAACZZ43PAAADPklEQVR4AWxSg3IsURCdT9gUY9s2VrFt27Zt27btxbNt27bn3U5VuNvD2zh9Gti2EAgEQSKZHIPtETFJSQsKhaK3V0c1No4BX+ygODg4BBSXVyw1NTU1IAdiUGhogKdfIK2trY1WVlYWgHQGweGRDQkpaUseHh4BELMve0lpxYqwqNg9XX39817e3seJJPIJO3uHu47OLnft7OxOunt4HJdXULisrq5+ra29fWWHBUKrQhmOKKuonknPzsNj45PuJ6em400trbi0tPRNePr7B/DGxib8ydNn+MYmDTcwMDhTVlFBoxqZVGHp6ekZKmrql4srqnEODo736MEPPqqqar/WNzZ/iYqKXgIfANHS1j5v4+CUAfQVTc0tmQlJKTi7YB8fH3xwcOiqpqbmkW0dsIGYnTJ09UmMvoFBlmBwDI+MPKyiokJbXFq+ua2fnpnFTc0sGNi26BFJjPHJqZ1APj6+t+BENTSkwxn14AI8RCJxTUFB8RzYEDPG9gQUiRQqrbqm5h04oy6/Gh0bf8HFxXUDsgL1bQBzC4sTSUlJN6AHnp6eNIhFTczMQOM57+Hp+SAuPv49AjqGGJxxcnFhQFBYWBgTvkh3d2Ji6qMBkXjaxcXlupu7+3EnV/dUrLi4uMTWzu4CoDo5OdMysrIOQ9ZtAGBFJJLOA20eHp6tPggJCT3w9fO/vTWFpubmHlTPGUFBwfNgBNrXb9z8CAAI6LAdAu/t6/93cMRhEZG4rZNLJ9bW1pGlra19DM34yXbDIFhVVZWOwG+gRbt3cDpiYmI30BjvO7l5lWClpaW+qLvLtXX138CYmZl5BFG9PTU981tGRuYWu92Iikv4oqOnv4hAYmAKhMLCwk5zc4sT4eHh93V1dU9Avf8nLCz8EZvm2MSk52YWlicSU9JWgPSCoxKUZdva21eoqakdhqX7qKioe+Li4s9FRUWfObu4nc0vKvmYlV/0X0NTc1dpReVmIyMjW5QcGRwcrNfQ2LzAHZhEraytrwBz4j1QQCWnpf/3Cwi45+TsfCUqKuZAd0/fAg8/Pz0GLACRsJxcU3wDgiYFh0cdAeXU/v7+juTk5BRwwiEFmJubRwQGBkbgUwMAJLm6C4IEadwAAAAASUVORK5CYII="

def main(config):
    scenario = config.get("_fixture_scenario", "")
    snapshot = fixture_snapshot(scenario)
    if snapshot == None:
        raw = config.get("$provider_data", "")
        if raw == "":
            return render.Root(child = neutral_page(provider_error(config)))
        snapshot = json.decode(raw)

    mode = config.get("mode", "favorite")
    team_id = str(config.get("teamid", "10"))

    # Compatibility: historical teamid=0 selected a random league team.
    # The deterministic successor is the All Live Games mode.
    if team_id == "0":
        mode = "all_live"

    games = snapshot.get("games", [])
    stale = snapshot.get("stale", False)
    if mode == "all_live":
        pages = [game_page(game, config, stale) for game in games if is_live(game)]
        if len(pages) == 0:
            pages = [no_live_page(snapshot.get("nextGame"), config, stale)]
        return animation(pages, config)

    if len(games) == 0:
        if config.bool("gameday", False):
            return []
        return render.Root(child = no_live_page(snapshot.get("nextGame"), config, stale))
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
    away = game.get("awayTeam", {})
    home = game.get("homeTeam", {})
    status = game.get("status", "unknown")
    score_visible = status in ["live", "intermission", "final"]
    stale = snapshot_stale or game.get("stale", False)
    return render.Column(
        expanded = True,
        children = [
            compact_header("NHL", "STALE" if stale else display_status(game, config), stale),
            team_row(away, game.get("awayScore", 0) if score_visible else "", config),
            team_row(home, game.get("homeScore", 0) if score_visible else "", config),
        ],
    )

def team_row(team, score, config):
    style = config.get("team_color_background_style", "dim")
    primary = safe_color(team.get("primaryColor", "#222222"))
    background = "#000000"
    if style == "full":
        background = primary
    elif style == "dim":
        background = dim_color(primary)
    return render.Box(
        width = 64,
        height = 12,
        color = background,
        child = render.Row(
            expanded = True,
            main_align = "space_between",
            cross_align = "center",
            children = [team_mark(team, background), render.Text(content = team.get("abbreviation", "?")[:3], color = "#ffffff", font = "tb-8"), render.Text(content = str(score)[:5], color = "#ffffff", font = "tb-8")],
        ),
    )

def no_live_page(next_game, config, stale):
    if next_game == None:
        return neutral_page("STALE" if stale else "NO GAME")
    away = next_game.get("awayTeam", {})
    home = next_game.get("homeTeam", {})
    return render.Column(
        expanded = True,
        children = [
            compact_header("NHL", "STALE" if stale else "NEXT", stale),
            render.Box(width = 64, height = 16, child = render.Row(
                expanded = True,
                main_align = "space_around",
                cross_align = "center",
                children = [compact_team(away), render.Text(content = "@", color = "#8e8e93", font = FONT), compact_team(home)],
            )),
            render.Box(width = 64, height = 8, child = render.Row(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = [render.Text(content = compact_start(next_game.get("scheduledAt", ""), config), color = "#ffcc00" if stale else "#ffffff", font = FONT)],
            )),
        ],
    )

def compact_header(league, status, stale = False):
    return render.Box(width = 64, height = 8, child = render.Row(
        expanded = True,
        main_align = "space_between",
        cross_align = "center",
        children = [render.Text(content = league, color = "#8e8e93", font = FONT), render.Text(content = status[:11], color = "#ffcc00" if stale else status_color(status), font = FONT)],
    ))

def compact_team(team):
    background = dim_color(safe_color(team.get("primaryColor", "#222222")))
    return render.Row(children = [team_mark(team, background), render.Text(content = team.get("abbreviation", "?")[:3], color = "#ffffff", font = FONT)])

def team_mark(team, background):
    logo = team.get("logoData", "")
    if logo != "":
        return render.Box(width = 14, height = 12, child = render.Image(src = base64.decode(logo), width = 12, height = 12))
    return render.Box(width = 14, height = 12, child = render.Box(width = 10, height = 10, color = background))

def compact_start(value, config):
    if value == "":
        return "TBD"
    return time.parse_time(value).in_location(config.get("$tz", "UTC")).format("Mon 3:04").upper()[:15]

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
    status = game.get("status", "unknown")
    if status in ["scheduled", "pregame"]:
        value = game.get("scheduledAt", "")
        return ("PRE " + local_clock(value, config)) if status == "pregame" else compact_start(value, config)
    detail = game.get("statusDetail", "")
    if status == "live" and detail != "":
        return detail[:11]
    return {
        "intermission": "INT",
        "delayed": "DLY",
        "suspended": "SUSP",
        "postponed": "PPD",
        "cancelled": "CANCEL",
        "final": "FINAL " + game.get("periodLabel", "") if game.get("periodLabel", "") in ["OT", "SO"] else "FINAL",
    }.get(status, "UNKNOWN")

def local_clock(value, config):
    if value == "":
        return "TBD"
    return time.parse_time(value).in_location(config.get("$tz", "UTC")).format("3:04")

def is_live(game):
    return game.get("status", "") in ["live", "intermission"]

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
    if status in ["live", "intermission"]:
        return "#30d158"
    if status in ["delayed", "suspended", "postponed", "cancelled"]:
        return "#ff9f0a"
    if status == "final":
        return "#8e8e93"
    return "#ffffff"

def safe_color(value):
    if len(value) == 7 and value[0] == "#":
        return value
    return "#222222"

def dim_color(value):
    # Pixlet accepts #RRGGBBAA. Preserve team identity at low intensity so
    # white score text remains readable on a physical matrix.
    return value + "55"

def provider_error(config):
    raw = config.get("$provider_error", "")
    if raw == "":
        return "DATA UNAVAILABLE"
    code = json.decode(raw).get("code", "")
    if code == "sports_team_invalid":
        return "CHOOSE TEAM"
    return "DATA UNAVAILABLE"

def fixture_team(team_id, abbreviation, color, with_logo = True):
    team = {"providerId": str(team_id), "abbreviation": abbreviation, "primaryColor": color}
    if with_logo:
        team["logoData"] = FIXTURE_LOGO
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
