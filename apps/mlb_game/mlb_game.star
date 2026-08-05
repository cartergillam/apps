# mlb_score_patched.star
# title: MLB Scoreboard (Photo Style • Bases Right • White-outlined filled bases • Centered counts)
# description: Left = two team tiles (away/home). Right = bases + count. Pixlet 0.50.1+

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

NO_GAME_RETRY = "30m"

# ----------------------- Defaults (BOS @ NYY) ---------------------------------
def default_game():
    return {
        "away": "PIT",
        "home": "PHI",
        "away_mark": "P",
        "home_mark": "P",
        "ascore": 1,
        "hscore": 3,
        "inning": "3",
        "top": False,  # ▲ = top, ▼ = bottom
        "balls": 1,
        "strikes": 2,
        "outs": 2,
        "on1": False,
        "on2": False,
        "on3": True,
        "away_bg": "#000000",
        "home_bg": "#7a0000",
        "away_logo_url": "",
        "home_logo_url": "",
        "is_final": False,
        "is_preview": False,
        "start_text": "",
        "game_label": "",
        "has_game": False,
        "fetch_ok": False,
        "failure_reason": "",
    }

# ----------------------- Tiny helpers -----------------------------------------
def spacer_w(w):
    return render.Box(width = w, height = 1)

def spacer_h(h):
    return render.Box(width = 1, height = h)

def px(c):
    return render.Box(width = 1, height = 1, color = c)

def clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v

# Safe accessors (no exceptions)
def as_str(x, d):
    return x if (x != None and type(x) == "string") else d

def as_int(x, d):
    return x if (x != None and type(x) == "int") else d

def as_bool(x, d):
    return x if (x != None and type(x) == "bool") else d

def as_text(x, d):
    if x == None:
        return d
    if type(x) == "string":
        return x
    if type(x) == "int":
        return str(x)
    return d

def int_from_digits(s, d):
    if type(s) != "string" or len(s) == 0:
        return d
    for i in range(len(s)):
        ch = s[i]
        if ch < "0" or ch > "9":
            return d
    return int(s)

def tz_suffix(tz):
    if tz == "America/New_York":
        return "ET"
    if tz == "America/Chicago":
        return "CT"
    if tz == "America/Denver":
        return "MT"
    if tz == "America/Los_Angeles":
        return "PT"
    if tz == "America/Anchorage":
        return "AKT"
    if tz == "Pacific/Honolulu":
        return "HT"
    return ""

def format_start_text(game_date, timezone):
    # MLB gameDate is RFC3339-like: 2026-02-23T18:35:00Z
    if type(game_date) != "string" or len(game_date) < 16:
        return "TBD"
    tz = as_str(timezone, "")
    if tz == "":
        tz = as_str(time.tz(), "")
    if tz == "":
        tz = "America/New_York"
    t = time.parse_time(game_date).in_location(tz)
    suffix = tz_suffix(tz)
    if suffix != "":
        return t.format("3:04") + " " + suffix
    return t.format("3:04")

def configured_timezone(config):
    # Tronbyt injects the device timezone as $tz. Keep the older plain
    # timezone key as a compatibility fallback for direct Pixlet configs.
    tz = as_str(config.get("$tz"), "")
    if tz == "":
        tz = as_str(config.get("timezone"), "")
    if tz == "" or tz == "Local":
        tz = "America/Toronto"
    return tz

def schedule_request_window(now, timezone):
    # Request a buffer around the device-local day. Selection below still uses
    # the exact local date, so UTC midnight and month boundaries cannot move a
    # device to tomorrow early.
    local_now = now.in_location(timezone)
    return {
        "device_date": local_now.format("2006-01-02"),
        "start_date": (local_now - time.parse_duration("36h")).format("2006-01-02"),
        "end_date": (local_now + time.parse_duration("36h")).format("2006-01-02"),
        "server_utc": now.in_location("UTC").format("2006-01-02T15:04:05Z"),
    }

# ----------------------- MLB lookup helpers -----------------------------------
TEAM_BY_ID = {
    108: "LAA",
    109: "ARI",
    110: "BAL",
    111: "BOS",
    112: "CHC",
    113: "CIN",
    114: "CLE",
    115: "COL",
    116: "DET",
    117: "HOU",
    118: "KC",
    119: "LAD",
    120: "WSH",
    121: "NYM",
    133: "ATH",
    134: "PIT",
    135: "SD",
    136: "SEA",
    137: "SF",
    138: "STL",
    139: "TB",
    140: "TEX",
    141: "TOR",
    142: "MIN",
    143: "PHI",
    144: "ATL",
    145: "CWS",
    146: "MIA",
    147: "NYY",
    158: "MIL",
}

TEAM_ID_BY_CODE = {
    "LAA": 108,
    "AZ": 109,
    "BAL": 110,
    "BOS": 111,
    "CHC": 112,
    "CIN": 113,
    "CLE": 114,
    "COL": 115,
    "DET": 116,
    "HOU": 117,
    "KC": 118,
    "LAD": 119,
    "WSH": 120,
    "NYM": 121,
    "ATH": 133,
    "PIT": 134,
    "SD": 135,
    "SEA": 136,
    "SF": 137,
    "STL": 138,
    "TB": 139,
    "TEX": 140,
    "TOR": 141,
    "MIN": 142,
    "PHI": 143,
    "ATL": 144,
    "CWS": 145,
    "MIA": 146,
    "NYY": 147,
    "MIL": 158,
    "ARI": 109,
}

def configured_team(value, fallback_id = 111):
    if type(value) == "int" and value in TEAM_BY_ID:
        return {"id": value, "code": TEAM_BY_ID[value]}
    text = as_str(value, "")
    if text in TEAM_ID_BY_CODE:
        return {"id": TEAM_ID_BY_CODE[text], "code": text}
    numeric = int_from_digits(text, 0)
    if numeric in TEAM_BY_ID:
        return {"id": numeric, "code": TEAM_BY_ID[numeric]}
    return {"id": fallback_id, "code": TEAM_BY_ID.get(fallback_id, "BOS")}

TEAM_BG = {
    "ARI": "#A71930",
    "ATH": "#003831",
    "ATL": "#CE1141",
    "AZ": "#A71930",
    "BAL": "#DF4601",
    "BOS": "#BD3039",
    "CHC": "#0E3386",
    "CIN": "#C6011F",
    "CLE": "#0C2340",
    "COL": "#333366",
    "CWS": "#27251F",
    "DET": "#0C2340",
    "HOU": "#002D62",
    "KC": "#004687",
    "LAA": "#BA0021",
    "LAD": "#005A9C",
    "MIA": "#00A3E0",
    "MIL": "#12284B",
    "MIN": "#002B5C",
    "NYM": "#002D72",
    "NYY": "#132448",
    "PHI": "#E81828",
    "PIT": "#27251F",
    "SD": "#2F241D",
    "SEA": "#0C2C56",
    "SF": "#FD5A1E",
    "STL": "#C41E3A",
    "TB": "#092C5C",
    "TEX": "#003278",
    "TOR": "#134A8E",
    "WSH": "#AB0003",
}

ALT_COLOR = {
    "HOU": "#002D62",
    "LAD": "#005A9C",
    "WSH": "#AB0003",
    "PIT": "#111111",
}

ALT_LOGO = {
    "PHI": "https://b.fssta.com/uploads/application/mlb/team-logos/Phillies-alternate.png",
    "DET": "https://b.fssta.com/uploads/application/mlb/team-logos/Tigers-alternate.png",
    "CIN": "https://b.fssta.com/uploads/application/mlb/team-logos/Reds-alternate.png",
    "STL": "https://b.fssta.com/uploads/application/mlb/team-logos/Cardinals-alternate.png",
}

LOGO_SIZE = {
    "ARI": 18,
    "ATL": 18,
    "CWS": 22,
    "DET": 18,
    "HOU": 18,
    "LAA": 22,
    "LAD": 18,
    "MIA": 18,
    "NYM": 18,
    "SF": 18,
    "SEA": 18,
    "TOR": 18,
}

TEAM_LOGO_KEY = {
    "ARI": "ari",
    "AZ": "ari",
    "ATH": "oak",
    "ATL": "atl",
    "BAL": "bal",
    "BOS": "bos",
    "CHC": "chc",
    "CIN": "cin",
    "CLE": "cle",
    "COL": "col",
    "CWS": "chw",
    "DET": "det",
    "HOU": "hou",
    "KC": "kc",
    "LAA": "laa",
    "LAD": "lad",
    "MIA": "mia",
    "MIL": "mil",
    "MIN": "min",
    "NYM": "nym",
    "NYY": "nyy",
    "PHI": "phi",
    "PIT": "pit",
    "SD": "sd",
    "SEA": "sea",
    "SF": "sf",
    "STL": "stl",
    "TB": "tb",
    "TEX": "tex",
    "TOR": "tor",
    "WSH": "wsh",
}

HEX_VAL = {
    "0": 0,
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
    "5": 5,
    "6": 6,
    "7": 7,
    "8": 8,
    "9": 9,
    "a": 10,
    "b": 11,
    "c": 12,
    "d": 13,
    "e": 14,
    "f": 15,
    "A": 10,
    "B": 11,
    "C": 12,
    "D": 13,
    "E": 14,
    "F": 15,
}

def lookup_team_code(team):
    if type(team) != "dict":
        return "MLB"
    code = as_str(team.get("abbreviation"), "")
    if code != "":
        return code
    tid = as_int(team.get("id"), 0)
    if tid in TEAM_BY_ID:
        return TEAM_BY_ID[tid]
    name = as_str(team.get("name"), "MLB")
    if len(name) >= 3:
        return name[:3]
    return name

def is_hex_digit(ch):
    return ch in HEX_VAL

def normalize_hex_color(s):
    if type(s) != "string":
        return ""
    if len(s) == 6:
        for i in range(6):
            if not is_hex_digit(s[i]):
                return ""
        return "#" + s
    if len(s) == 7 and s[0] == "#":
        for i in range(1, 7):
            if not is_hex_digit(s[i]):
                return ""
        return s
    return ""

def team_bg_for(code, espn_color):
    c = as_str(code, "")
    col = normalize_hex_color(espn_color)
    if c in ALT_COLOR:
        col = ALT_COLOR[c]
    elif col == "":
        if c in TEAM_BG:
            col = TEAM_BG[c]
        else:
            col = "#202020"
    if col == "#ffffff" or col == "#000000":
        return "#222222"
    return col

def get_espn_team_map():
    out = {}
    url = "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard?limit=100"
    resp = http.get(url = url, ttl_seconds = 120)
    if resp.status_code != 200:
        return out
    body = resp.body()
    if body == None or len(body) == 0 or body[0] != "{":
        return out
    parsed = json.decode(body)
    if type(parsed) != "dict":
        return out
    events = parsed.get("events")
    if type(events) != "list":
        return out
    for ev in events:
        if type(ev) != "dict":
            continue
        comps = ev.get("competitions")
        if type(comps) != "list" or len(comps) == 0:
            continue
        comp = comps[0]
        if type(comp) != "dict":
            continue
        competitors = comp.get("competitors")
        if type(competitors) != "list":
            continue
        for ct in competitors:
            if type(ct) != "dict":
                continue
            t = ct.get("team")
            if type(t) != "dict":
                continue
            abbr = as_str(t.get("abbreviation"), "")
            if abbr == "":
                continue
            color = normalize_hex_color(t.get("color"))
            logo = as_str(t.get("logo"), "")
            out[abbr] = {
                "color": color,
                "logo": logo,
            }
    return out

def get_mlb_team_ids():
    out = {}
    url = "https://statsapi.mlb.com/api/v1/teams?sportId=1&activeStatus=Y"
    resp = http.get(url = url, ttl_seconds = 86400)
    if resp.status_code == 200:
        body = resp.body()
        if body != None and len(body) > 0 and body[0] == "{":
            parsed = json.decode(body)
            if type(parsed) == "dict":
                teams = parsed.get("teams")
                if type(teams) == "list":
                    for team in teams:
                        if type(team) != "dict":
                            continue
                        team_id = as_int(team.get("id"), 0)
                        if team_id > 0:
                            out[team_id] = True
    if len(out) > 0:
        return out

    for team_id in TEAM_BY_ID:
        out[team_id] = True
    return out

def hex_byte(s, start):
    if type(s) != "string" or len(s) < start + 2:
        return 0
    hi = s[start]
    lo = s[start + 1]
    if hi not in HEX_VAL or lo not in HEX_VAL:
        return 0
    return HEX_VAL[hi] * 16 + HEX_VAL[lo]

def team_font_color(bg):
    if type(bg) != "string" or len(bg) != 7 or bg[0] != "#":
        return "#ffffff"
    r = hex_byte(bg, 1)
    g = hex_byte(bg, 3)
    b = hex_byte(bg, 5)

    # Weighted luminance for simple contrast selection.
    lum = (r * 299 + g * 587 + b * 114) / 1000
    if lum >= 140:
        return "#111111"
    return "#ffffff"

def mark_for(code):
    c = as_str(code, "")
    if len(c) > 0:
        return c[0]
    return "M"

def get_cachable_data(url, ttl_seconds):
    res = http.get(url = url, ttl_seconds = ttl_seconds)
    if res.status_code != 200:
        return None
    body = res.body()
    if body == None or len(body) == 0:
        return None
    return body

def logo_url_for(code, espn_logo_url):
    c = as_str(code, "")
    if c in ALT_LOGO:
        return ALT_LOGO[c]
    url = as_str(espn_logo_url, "")
    if url != "":
        url = url.replace("500/scoreboard", "500-dark/scoreboard")
        url = url.replace("https://a.espncdn.com/", "https://a.espncdn.com/combiner/i?img=")
        if "&h=" not in url and "&w=" not in url:
            url = url + "&h=50&w=50"
        return url
    if c in TEAM_LOGO_KEY:
        return "https://a.espncdn.com/i/teamlogos/mlb/500-dark/" + TEAM_LOGO_KEY[c] + ".png"
    return ""

def team_logo_for(code, espn_logo_url):
    url = logo_url_for(code, espn_logo_url)
    if url == "":
        return None
    return get_cachable_data(url, 36000)

def team_logo_size_for(code):
    c = as_str(code, "")
    if c in LOGO_SIZE:
        return LOGO_SIZE[c]
    return 16

def fit_logo_size(code):
    s = team_logo_size_for(code)
    if s > 14:
        s = 14
    if s < 12:
        s = 12
    return s

def sprite_row(pattern, on_color):
    pixels = []
    for i in range(len(pattern)):
        ch = pattern[i]
        pixels.append(px(on_color if ch == "#" else "#000000"))
    return render.Row(children = pixels, main_align = "start", cross_align = "start")

def sprite(rows, on_color):
    line_rows = []
    for r in rows:
        line_rows.append(sprite_row(r, on_color))
    return render.Column(children = line_rows, main_align = "start", cross_align = "start")

def sprite_row_palette(pattern, palette):
    pixels = []
    for i in range(len(pattern)):
        ch = pattern[i]
        col = palette.get(ch)
        if col == None:
            col = "#000000"
        pixels.append(px(col))
    return render.Row(children = pixels, main_align = "start", cross_align = "start")

def sprite_palette(rows, palette):
    line_rows = []
    for r in rows:
        line_rows.append(sprite_row_palette(r, palette))
    return render.Column(children = line_rows, main_align = "start", cross_align = "start")

def team_logo_sprite(code3, fg, espn_logo_url):
    c = as_str(code3, "")
    img = team_logo_for(c, espn_logo_url)
    if img != None:
        size = fit_logo_size(c)
        return render.Box(
            width = 14,
            height = 14,
            child = render.Column(
                children = [
                    render.Row(
                        children = [render.Image(img, width = size, height = size)],
                        main_align = "center",
                        cross_align = "center",
                    ),
                ],
                main_align = "start",
                cross_align = "stretch",
            ),
        )
    return render.Text(mark_for(c), font = "6x13", color = fg)

def has_runner(offense, key):
    if type(offense) != "dict":
        return False
    return type(offense.get(key)) == "dict"

def is_public_facing_game(game):
    if type(game) != "dict":
        return False
    public_facing = game.get("publicFacing")
    if public_facing == None:
        return True
    if type(public_facing) == "bool":
        return public_facing
    if type(public_facing) == "string":
        return public_facing == "True"
    return True

def has_tracked_linescore(game):
    if type(game) != "dict":
        return False
    linescore = game.get("linescore")
    if type(linescore) != "dict":
        return False
    innings = linescore.get("innings")
    if type(innings) == "list" and len(innings) > 0:
        return True

    if linescore.get("currentInning") != None:
        return True

    teams = linescore.get("teams")
    if type(teams) == "dict":
        home = teams.get("home")
        away = teams.get("away")
        if type(home) == "dict" and len(home) > 0:
            return True
        if type(away) == "dict" and len(away) > 0:
            return True

    offense = linescore.get("offense")
    if type(offense) == "dict":
        if type(offense.get("batter")) == "dict" or type(offense.get("onDeck")) == "dict" or type(offense.get("inHole")) == "dict":
            return True

    defense = linescore.get("defense")
    if type(defense) == "dict":
        if type(defense.get("pitcher")) == "dict" or type(defense.get("catcher")) == "dict":
            return True

    return False

def is_mlb_team(team, mlb_team_ids):
    if type(team) != "dict":
        return False
    team_id = as_int(team.get("id"), 0)
    if team_id in mlb_team_ids:
        return True
    team_code = lookup_team_code(team)
    if team_code in TEAM_ID_BY_CODE:
        return True
    return team_code in TEAM_BG

def has_only_mlb_opponents(game, mlb_team_ids):
    if type(game) != "dict":
        return False
    teams = game.get("teams")
    if type(teams) != "dict":
        return False
    away_info = teams.get("away")
    home_info = teams.get("home")
    if type(away_info) != "dict" or type(home_info) != "dict":
        return False
    away_team = away_info.get("team")
    home_team = home_info.get("team")
    return is_mlb_team(away_team, mlb_team_ids) and is_mlb_team(home_team, mlb_team_ids)

def game_has_team_id(game, team_id):
    if type(game) != "dict":
        return False
    if team_id <= 0:
        return True
    teams = game.get("teams")
    if type(teams) != "dict":
        return False
    away_info = teams.get("away")
    home_info = teams.get("home")
    away_team = away_info.get("team") if type(away_info) == "dict" else None
    home_team = home_info.get("team") if type(home_info) == "dict" else None
    away_id = as_int(away_team.get("id"), 0) if type(away_team) == "dict" else 0
    home_id = as_int(home_team.get("id"), 0) if type(home_team) == "dict" else 0
    return away_id == team_id or home_id == team_id

def game_local_date(game, timezone):
    if type(game) != "dict":
        return ""
    official_date = as_str(game.get("officialDate"), "")
    game_date = as_str(game.get("gameDate"), "")
    if game_date != "" and len(game_date) >= 16:
        return time.parse_time(game_date).in_location(timezone).format("2006-01-02")
    return official_date

def game_sort_key(game):
    if type(game) != "dict":
        return 999
    num = as_int(game.get("gameNumber"), 0)
    if num > 0:
        return num
    game_date = as_str(game.get("gameDate"), "")
    if len(game_date) >= 16:
        hh = int_from_digits(game_date[11:13], 0)
        mm = int_from_digits(game_date[14:16], 0)
        return hh * 60 + mm
    return 999

def game_rank(game):
    if type(game) != "dict":
        return -1
    status = game.get("status")
    if type(status) != "dict":
        return 0
    state = as_str(status.get("abstractGameState"), "")
    detailed = as_str(status.get("detailedState"), "")
    if detailed == "Delayed Start" or detailed == "Postponed" or detailed == "Suspended":
        return 2
    if state == "Live" or detailed == "In Progress" or detailed == "Manager Challenge" or detailed == "Review":
        return 4
    if state == "Preview" or detailed in ["Scheduled", "Pre-Game", "Warmup"]:
        return 3
    if state == "Final":
        return 1
    return 0

def is_better_game(candidate, best):
    if type(candidate) != "dict":
        return False
    if type(best) != "dict":
        return True
    c_rank = game_rank(candidate)
    b_rank = game_rank(best)
    if c_rank != b_rank:
        return c_rank > b_rank
    c_key = game_sort_key(candidate)
    b_key = game_sort_key(best)
    if c_rank <= 1:
        return c_key > b_key
    return c_key < b_key

def select_game_info(games, include_exhibition_opponents, mlb_team_ids, selected_team_id):
    if type(games) != "list" or len(games) == 0:
        return None

    ordered = []
    for g in games:
        if type(g) != "dict":
            continue
        if not is_public_facing_game(g):
            continue
        if not include_exhibition_opponents and not has_only_mlb_opponents(g, mlb_team_ids):
            continue
        if not game_has_team_id(g, selected_team_id):
            continue
        insert_at = len(ordered)
        g_key = game_sort_key(g)
        for i in range(len(ordered)):
            if g_key < game_sort_key(ordered[i]):
                insert_at = i
                break
        ordered.insert(insert_at, g)

    if len(ordered) == 0:
        return None

    first_game = ordered[0]
    season_type = as_str(first_game.get("gameType"), "")
    if season_type != "R":
        return {
            "game": first_game,
            "game_label": "",
        }

    best = ordered[0]
    best_index = 1
    for i in range(len(ordered)):
        g = ordered[i]
        if is_better_game(g, best):
            best = g
            best_index = i + 1

    label = ""
    if len(ordered) > 1:
        label = "G" + str(best_index)

    return {
        "game": best,
        "game_label": label,
    }

def select_game_for_local_date(dates, device_date, timezone, include_exhibition_opponents, mlb_team_ids, selected_team_id):
    games = []
    if type(dates) != "list":
        return None
    for date_entry in dates:
        if type(date_entry) != "dict":
            continue
        date_games = date_entry.get("games")
        if type(date_games) != "list":
            continue
        for game in date_games:
            if game_local_date(game, timezone) == device_date:
                games.append(game)
    return select_game_info(games, include_exhibition_opponents, mlb_team_ids, selected_team_id)

# ----------------------- Bases (right-top tile) -------------------------------
def base_diamond(filled):
    rows = []
    for y in range(7):
        pixels = []
        for x in range(7):
            d = abs(x - 3) + abs(y - 3)
            col = "#000000"
            if d == 3:
                col = "#ffffff"
            elif d < 3 and filled:
                col = "#ffd24a"
            pixels.append(px(col))
        rows.append(render.Row(children = pixels, main_align = "start", cross_align = "start"))
    return render.Box(
        width = 7,
        height = 7,
        child = render.Column(children = rows, main_align = "start", cross_align = "start"),
    )

def bases_tile(on1, on2, on3):
    top = render.Row(children = [base_diamond(on2)], main_align = "center")
    mid = render.Row(
        children = [base_diamond(on3), spacer_w(3), base_diamond(on1)],
        main_align = "center",
    )
    return render.Box(
        height = 16,
        child = render.Column(
            children = [spacer_h(1), top, spacer_h(1), mid],
            main_align = "start",
            cross_align = "center",
        ),
    )

# ----------------------- Count (right-bottom tile) ----------------------------
# Requested change: center the strike/ball count and the OUT boxes.
def tiny_out_box(on):
    return render.Box(width = 3, height = 3, color = "#ffd24a" if on else "#2a2a2a")

def outs_row(outs):
    o = clamp(outs, 0, 2)
    left = tiny_out_box(o >= 1)
    right = tiny_out_box(o >= 2)
    return render.Row(children = [left, spacer_w(2), right], main_align = "center", cross_align = "center")

def tiny_arrow(top_half):
    rows = ["..w..", ".www.", "wwwww"] if top_half else ["wwwww", ".www.", "..w.."]
    return render.Box(width = 5, height = 3, child = sprite_palette(rows, {"w": "#ffffff"}))

def count_tile(inning, top_half, balls, strikes, outs, status_text, game_label):
    if status_text != "":
        status_child = render.Text(status_text, font = "6x10-rounded")
        if len(status_text) > 5:
            status_child = render.Text(status_text, font = "5x8")
        if len(status_text) >= 3 and (
            status_text[len(status_text) - 3:] == " ET" or
            status_text[len(status_text) - 3:] == " CT" or
            status_text[len(status_text) - 3:] == " MT" or
            status_text[len(status_text) - 3:] == " PT" or
            status_text[len(status_text) - 3:] == " HT" or
            (len(status_text) >= 4 and status_text[len(status_text) - 4:] == " AKT")
        ):
            suf_len = 2
            if len(status_text) >= 4 and status_text[len(status_text) - 4:] == " AKT":
                suf_len = 3
            status_child = render.Row(
                children = [
                    render.Text(status_text[:len(status_text) - 1 - suf_len], font = "5x8"),
                    spacer_w(1),
                    render.Text(status_text[len(status_text) - suf_len:], font = "CG-pixel-3x5-mono"),
                ],
                main_align = "center",
                cross_align = "center",
            )
        return render.Box(
            height = 16,
            child = render.Box(
                width = 29,
                child = render.Row(
                    children = [status_child],
                    expanded = True,
                    main_align = "center",
                    cross_align = "center",
                ),
            ),
        )

    left_children = [spacer_h(4)]
    if game_label != "":
        left_children = [
            spacer_h(1),
            render.Row(
                children = [render.Text(game_label, font = "CG-pixel-3x5-mono")],
                main_align = "start",
                cross_align = "center",
            ),
            spacer_h(1),
        ]
    left_col = render.Box(
        width = 10,
        height = 16,
        child = render.Column(
            children = left_children + [
                render.Row(
                    children = [
                        render.Column(
                            children = [spacer_h(3), tiny_arrow(top_half)],
                            main_align = "start",
                            cross_align = "start",
                        ),
                        spacer_w(1),
                        render.Text(str(inning), font = "5x8"),
                    ],
                    main_align = "start",
                    cross_align = "start",
                ),
            ],
            main_align = "start",
            cross_align = "start",
        ),
    )

    right_col = render.Box(
        width = 18,
        child = render.Column(
            children = [
                spacer_h(1),
                render.Row(
                    children = [render.Text(str(balls) + "-" + str(strikes), font = "5x8")],
                    main_align = "center",
                    cross_align = "center",
                ),
                spacer_h(1),
                render.Row(
                    children = [outs_row(outs)],
                    main_align = "center",
                    cross_align = "center",
                ),
            ],
            main_align = "start",
            cross_align = "center",
        ),
    )

    layout = render.Row(
        children = [
            spacer_w(1),
            left_col,
            right_col,
        ],
        main_align = "start",
        cross_align = "start",
    )

    return render.Box(
        height = 16,
        child = render.Column(
            children = [layout],
            main_align = "start",
            cross_align = "stretch",
        ),
    )

# ----------------------- Team tiles (left half) -------------------------------
def team_tile(bg, code3, score, logo_url, show_colored_background):
    tile_bg = bg if show_colored_background else "#000000"
    fg = team_font_color(tile_bg)
    left = render.Box(
        width = 14,
        child = render.Column(
            children = [
                render.Row(children = [team_logo_sprite(code3, fg, logo_url)], main_align = "center"),
            ],
            main_align = "start",
            cross_align = "center",
        ),
    )
    right = render.Box(
        width = 15,
        child = render.Column(children = [
            render.Row(
                children = [render.Text(code3, font = "CG-pixel-3x5-mono", color = fg)],
                main_align = "start",
                cross_align = "center",
            ),
            spacer_h(2),
            render.Row(
                children = [render.Text(str(score), font = "5x8", color = fg)],
                main_align = "start",
                cross_align = "center",
            ),
        ]),
    )
    row = render.Row(
        children = [left, spacer_w(4), right],
        main_align = "start",
        cross_align = "center",
    )
    return render.Box(color = tile_bg, height = 16, padding = 1, child = row)

# ----------------------- Panels ----------------------------------------------
def left_panel(away, home, ascore, hscore, away_bg, home_bg, away_logo_url, home_logo_url, show_colored_background):
    away_tile = team_tile(away_bg, away, ascore, away_logo_url, show_colored_background)
    home_tile = team_tile(home_bg, home, hscore, home_logo_url, show_colored_background)
    return render.Box(
        width = 36,
        child = render.Column(
            children = [away_tile, home_tile],
            main_align = "start",
            cross_align = "stretch",
        ),
    )

def game_label_tile(game_label):
    if game_label == "":
        return bases_tile(False, False, False)
    return render.Box(
        height = 16,
        child = render.Column(
            children = [
                spacer_h(4),
                render.Row(
                    children = [render.Text(game_label, font = "CG-pixel-3x5-mono")],
                    main_align = "center",
                    cross_align = "center",
                ),
            ],
            main_align = "start",
            cross_align = "center",
        ),
    )

def right_panel(on1, on2, on3, inning, top_half, balls, strikes, outs, is_final, is_preview, start_text, game_label):
    if is_final or is_preview:
        status_text = "Final" if is_final else start_text
        top = game_label_tile(game_label)
        bot = count_tile(inning, top_half, balls, strikes, outs, status_text, "")
        return render.Box(
            width = 28,
            child = render.Column(
                children = [top, bot],
                main_align = "start",
                cross_align = "stretch",
            ),
        )

    top = bases_tile(on1, on2, on3)
    bot = count_tile(inning, top_half, balls, strikes, outs, "", game_label)
    return render.Box(
        width = 29,
        child = render.Column(
            children = [top, bot],
            main_align = "start",
            cross_align = "stretch",
        ),
    )

# ----------------------- Fetch + cache (no try/except) ------------------------
def schedule_response_failure(status_code, body):
    if status_code != 200:
        return "schedule_http_" + str(status_code)
    if body == None or len(body) == 0:
        return "empty_schedule_response"
    if body[0] != "{":
        return "malformed_schedule_response"
    return ""

def get_game_data(config):
    d = default_game()
    espn_teams = get_espn_team_map()
    mlb_team_ids = get_mlb_team_ids()
    include_exhibition_opponents = config.bool("include_exhibition_opponents", False)

    selected_team = configured_team(config.get("team"))
    team_id = selected_team["id"]

    timezone = configured_timezone(config)
    request_window = schedule_request_window(time.now(), timezone)
    schedule_url = (
        "https://statsapi.mlb.com/api/v1/schedule?sportId=1&teamId=" + str(team_id) +
        "&startDate=" + request_window["start_date"] +
        "&endDate=" + request_window["end_date"] +
        "&hydrate=linescore"
    )
    print(
        "MLB schedule request: local_date=" + request_window["device_date"] +
        " timezone=" + timezone +
        " server_utc=" + request_window["server_utc"] +
        " range=" + request_window["start_date"] + ".." + request_window["end_date"] +
        " team_id=" + str(team_id),
    )

    resp = http.get(url = schedule_url, ttl_seconds = 120)
    body = resp.body()
    failure_reason = schedule_response_failure(resp.status_code, body)
    if failure_reason != "":
        d["failure_reason"] = failure_reason
        return d

    parsed = json.decode(body)
    if type(parsed) != "dict":
        d["failure_reason"] = "malformed_schedule_response"
        return d
    d["fetch_ok"] = True

    dates = parsed.get("dates")
    if type(dates) != "list" or len(dates) == 0:
        print("MLB schedule result: games_returned=0 hide_reason=no_dates")
        return d

    games_returned = 0
    for date_entry in dates:
        if type(date_entry) == "dict" and type(date_entry.get("games")) == "list":
            games_returned += len(date_entry.get("games"))
    game_info = select_game_for_local_date(
        dates,
        request_window["device_date"],
        timezone,
        include_exhibition_opponents,
        mlb_team_ids,
        team_id,
    )
    if type(game_info) != "dict":
        print("MLB schedule result: games_returned=" + str(games_returned) + " selected_game_id=none hide_reason=no_eligible_local_game")
        return d

    game = game_info.get("game")
    if type(game) != "dict":
        return d

    d["has_game"] = True
    d["game_label"] = as_str(game_info.get("game_label"), "")

    status = game.get("status")
    if type(status) == "dict":
        state = as_str(status.get("abstractGameState"), "")
        d["is_final"] = (state == "Final")
        detailed = as_str(status.get("detailedState"), "")
        d["is_preview"] = state == "Preview" or detailed in ["Scheduled", "Pre-Game", "Warmup", "Delayed Start", "Postponed", "Suspended"]
        print(
            "MLB schedule result: games_returned=" + str(games_returned) +
            " selected_game_id=" + as_text(game.get("gamePk"), "unknown") +
            " selected_status=" + state + "/" + detailed +
            " hide_reason=none",
        )

    if d["is_preview"]:
        d["start_text"] = format_start_text(as_str(game.get("gameDate"), ""), timezone)

    teams = game.get("teams")
    if type(teams) == "dict":
        away_info = teams.get("away")
        home_info = teams.get("home")
        if type(away_info) == "dict" and type(home_info) == "dict":
            away_team = away_info.get("team")
            home_team = home_info.get("team")
            away_code = lookup_team_code(away_team)
            home_code = lookup_team_code(home_team)
            away_meta = espn_teams.get(away_code)
            home_meta = espn_teams.get(home_code)
            away_color = ""
            home_color = ""
            away_logo_url = ""
            home_logo_url = ""
            if type(away_meta) == "dict":
                away_color = as_str(away_meta.get("color"), "")
                away_logo_url = as_str(away_meta.get("logo"), "")
            if type(home_meta) == "dict":
                home_color = as_str(home_meta.get("color"), "")
                home_logo_url = as_str(home_meta.get("logo"), "")

            d["away"] = away_code
            d["home"] = home_code
            d["away_mark"] = mark_for(away_code)
            d["home_mark"] = mark_for(home_code)
            d["ascore"] = as_int(away_info.get("score"), 0)
            d["hscore"] = as_int(home_info.get("score"), 0)
            d["away_bg"] = team_bg_for(away_code, away_color)
            d["home_bg"] = team_bg_for(home_code, home_color)
            d["away_logo_url"] = away_logo_url
            d["home_logo_url"] = home_logo_url

    linescore = game.get("linescore")
    if type(linescore) == "dict":
        d["inning"] = as_text(linescore.get("currentInning"), 1)
        d["top"] = as_bool(linescore.get("isTopInning"), True)
        d["balls"] = clamp(as_int(linescore.get("balls"), 0), 0, 3)
        d["strikes"] = clamp(as_int(linescore.get("strikes"), 0), 0, 2)
        d["outs"] = clamp(as_int(linescore.get("outs"), 0), 0, 2)

        offense = linescore.get("offense")
        d["on1"] = has_runner(offense, "first")
        d["on2"] = has_runner(offense, "second")
        d["on3"] = has_runner(offense, "third")

    return d

# ----------------------- Main -------------------------------------------------
def assert_mlb_test(condition, message):
    if not condition:
        fail("MLB regression failed: " + message)

def regression_game(game_pk, game_date, away_id, home_id, state, detailed, game_number = 1):
    return {
        "gamePk": game_pk,
        "gameDate": game_date,
        "officialDate": game_date[:10],
        "gameType": "R",
        "gameNumber": game_number,
        "publicFacing": True,
        "status": {"abstractGameState": state, "detailedState": detailed},
        "teams": {
            "away": {"team": {"id": away_id, "abbreviation": TEAM_BY_ID.get(away_id, "UNK")}},
            "home": {"team": {"id": home_id, "abbreviation": TEAM_BY_ID.get(home_id, "UNK")}},
        },
        # A scheduled game legitimately has no tracked linescore before first pitch.
        "linescore": {"innings": [], "teams": {}},
    }

def run_mlb_regression_tests():
    timezone = "America/Toronto"
    utc_after_midnight = time.parse_time("2026-08-01T01:00:00Z")
    window = schedule_request_window(utc_after_midnight, timezone)
    assert_mlb_test(window["device_date"] == "2026-07-31", "UTC midnight changed the Toronto date")
    assert_mlb_test(window["start_date"] == "2026-07-30" and window["end_date"] == "2026-08-02", "safe month-boundary request range")

    scheduled = regression_game(822782, "2026-07-31T23:07:00Z", 138, 141, "Preview", "Scheduled")
    away = regression_game(822783, "2026-07-31T17:00:00Z", 141, 138, "Preview", "Pre-Game")
    august_game = regression_game(822784, "2026-08-01T16:00:00Z", 138, 141, "Preview", "Scheduled")
    dates = [
        {"date": "2026-07-31", "games": [scheduled]},
        {"date": "2026-08-01", "games": [august_game]},
    ]
    mlb_ids = {138: True, 141: True}
    selected = select_game_for_local_date(dates, "2026-07-31", timezone, False, mlb_ids, 141)
    assert_mlb_test(type(selected) == "dict", "scheduled Toronto game was filtered out")
    assert_mlb_test(as_int(selected["game"].get("gamePk"), 0) == 822782, "Toronto home pregame selection")
    assert_mlb_test(game_rank(scheduled) == 3, "scheduled pregame status is eligible")
    assert_mlb_test(type(select_game_info([away], False, mlb_ids, 141)) == "dict", "Toronto away game selection")

    after_utc_midnight = regression_game(822785, "2026-08-01T02:30:00Z", 138, 141, "Live", "In Progress")
    selected = select_game_for_local_date([{"date": "2026-08-01", "games": [after_utc_midnight]}], "2026-07-31", timezone, False, mlb_ids, 141)
    assert_mlb_test(type(selected) == "dict", "game after UTC midnight disappeared before local midnight")

    first_final = regression_game(822786, "2026-07-31T17:00:00Z", 138, 141, "Final", "Final", 1)
    second_scheduled = regression_game(822787, "2026-07-31T23:07:00Z", 138, 141, "Preview", "Warmup", 2)
    selected = select_game_info([first_final, second_scheduled], False, mlb_ids, 141)
    assert_mlb_test(as_int(selected["game"].get("gamePk"), 0) == 822787 and selected["game_label"] == "G2", "doubleheader selection")

    postponed = regression_game(822788, "2026-07-31T23:07:00Z", 138, 141, "Preview", "Postponed")
    delayed = regression_game(822789, "2026-07-31T23:07:00Z", 138, 141, "Preview", "Delayed Start")
    suspended = regression_game(822790, "2026-07-31T23:07:00Z", 138, 141, "Live", "Suspended")
    live = regression_game(822791, "2026-07-31T23:07:00Z", 138, 141, "Live", "In Progress")
    assert_mlb_test(type(select_game_info([postponed], False, mlb_ids, 141)) == "dict", "postponed game was hidden")
    assert_mlb_test(game_rank(delayed) == 2, "delayed game status")
    assert_mlb_test(game_rank(suspended) == 2, "suspended game status")
    assert_mlb_test(game_rank(live) == 4, "live game status")
    assert_mlb_test(game_rank(first_final) == 1, "final game status")
    assert_mlb_test(select_game_info([scheduled], False, mlb_ids, 147) == None, "wrong team ID matched")
    assert_mlb_test(configured_team("TOR")["id"] == 141 and configured_team("141")["id"] == 141 and configured_team(141)["code"] == "TOR", "team abbreviation/numeric mapping")
    assert_mlb_test(select_game_for_local_date([], "2026-07-31", timezone, False, mlb_ids, 141) == None, "empty response handling")
    assert_mlb_test(select_game_for_local_date([{"games": "invalid"}, "invalid"], "2026-07-31", timezone, False, mlb_ids, 141) == None, "malformed response shape")
    assert_mlb_test(schedule_response_failure(503, "{}") == "schedule_http_503", "upstream failure classification")
    assert_mlb_test(schedule_response_failure(200, "not-json") == "malformed_schedule_response", "malformed response classification")
    assert_mlb_test(NO_GAME_RETRY == "30m", "no-game retry must remain bounded")
    print("MLB regression tests passed")

def main(config):
    if config.bool("__run_regression_tests", False):
        run_mlb_regression_tests()
        return render.Root(child = render.Box(width = 64, height = 36, color = "#00ff00"))

    if config.bool("__fixture_render", False):
        d = default_game()
        d["has_game"] = True
        d["fetch_ok"] = True

        # Synthetic codes deliberately have no remote logo mapping, keeping this
        # gallery fixture deterministic and fully offline.
        d["away"] = "AWY"
        d["home"] = "HME"
        d["away_bg"] = "#134A8E"
        d["home_bg"] = "#C41E3A"
        d["is_preview"] = True
        d["start_text"] = "7:07 PM"
    else:
        d = get_game_data(config)

    if config.bool("gameday_only", False) and not d["fetch_ok"]:
        print("TRONBYT-RENDER-FAILURE: " + as_str(d["failure_reason"], "schedule_unavailable"))
        return []

    if config.bool("gameday_only", False) and d["fetch_ok"] and not d["has_game"]:
        print("--- APPLET HIDDEN FROM ROTATION (NO GAME TODAY) ---")
        next_check = time.now() + time.parse_duration(NO_GAME_RETRY)
        print("TRONBYT-HIDDEN-UNTIL: " + next_check.in_location("UTC").format("2006-01-02T15:04:05Z"))
        return []

    show_colored_background = config.bool("show_team_colored_logo_background", True)

    # Compatibility for installations created by an earlier iOS-only spelling.
    if config.get("show_team_colored_logo_background") == None and config.get("show_team_coloured_logo_background") != None:
        show_colored_background = config.bool("show_team_coloured_logo_background", True)

    # Optional manual overrides
    for k in ["away", "home", "away_mark", "home_mark", "inning", "away_bg", "home_bg"]:
        v = config.get(k)
        if v != None:
            d[k] = str(v)
    for k in ["ascore", "hscore", "balls", "strikes", "outs"]:
        v = config.get(k)
        if v != None and type(v) == "int":
            d[k] = v
    for k in ["top", "on1", "on2", "on3"]:
        v = config.get(k)
        if v != None and type(v) == "bool":
            d[k] = v

    return render.Root(
        child = render.Box(
            color = "#000000",
            child = render.Row(
                children = [
                    left_panel(
                        d["away"],
                        d["home"],
                        d["ascore"],
                        d["hscore"],
                        d["away_bg"],
                        d["home_bg"],
                        d["away_logo_url"],
                        d["home_logo_url"],
                        show_colored_background,
                    ),
                    right_panel(
                        d["on1"],
                        d["on2"],
                        d["on3"],
                        d["inning"],
                        d["top"],
                        d["balls"],
                        d["strikes"],
                        d["outs"],
                        d["is_final"],
                        d["is_preview"],
                        d["start_text"],
                        d["game_label"],
                    ),
                ],
                main_align = "start",
                cross_align = "start",
            ),
        ),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "team",
                name = "Team Focus",
                desc = "Only show scores for selected team.",
                icon = "gear",
                default = teamOptions[0].value,
                options = teamOptions,
            ),
            schema.Toggle(
                id = "gameday_only",
                name = "Show only on game day",
                desc = "Hide app from rotation when no game is scheduled for selected team/date.",
                icon = "calendar",
                default = False,
            ),
            schema.Toggle(
                id = "include_exhibition_opponents",
                name = "Include non-MLB opponents",
                desc = "Show exhibitions against international, national, or other non-MLB teams.",
                icon = "gear",
                default = False,
            ),
            schema.Toggle(
                id = "show_team_colored_logo_background",
                name = "Team-colour background",
                desc = "Show each team logo and score on the team's color. Turn off for a clean black background.",
                icon = "baseball",
                default = True,
            ),
        ],
    )

teamOptions = [
    schema.Option(
        display = "Arizona Diamondbacks",
        value = "109",
    ),
    schema.Option(
        display = "Athletics",
        value = "133",
    ),
    schema.Option(
        display = "Atlanta Braves",
        value = "144",
    ),
    schema.Option(
        display = "Baltimore Orioles",
        value = "110",
    ),
    schema.Option(
        display = "Boston Red Sox",
        value = "111",
    ),
    schema.Option(
        display = "Chicago Cubs",
        value = "112",
    ),
    schema.Option(
        display = "Chicago White Sox",
        value = "145",
    ),
    schema.Option(
        display = "Cincinnati Reds",
        value = "113",
    ),
    schema.Option(
        display = "Cleveland Guardians",
        value = "114",
    ),
    schema.Option(
        display = "Colorado Rockies",
        value = "115",
    ),
    schema.Option(
        display = "Detroit Tigers",
        value = "116",
    ),
    schema.Option(
        display = "Houston Astros",
        value = "117",
    ),
    schema.Option(
        display = "Kansas City Royals",
        value = "118",
    ),
    schema.Option(
        display = "Los Angeles Angels",
        value = "108",
    ),
    schema.Option(
        display = "Los Angeles Dodgers",
        value = "119",
    ),
    schema.Option(
        display = "Miami Marlins",
        value = "146",
    ),
    schema.Option(
        display = "Milwaukee Brewers",
        value = "158",
    ),
    schema.Option(
        display = "Minnesota Twins",
        value = "142",
    ),
    schema.Option(
        display = "New York Mets",
        value = "121",
    ),
    schema.Option(
        display = "New York Yankees",
        value = "147",
    ),
    schema.Option(
        display = "Philadelphia Phillies",
        value = "143",
    ),
    schema.Option(
        display = "Pittsburgh Pirates",
        value = "134",
    ),
    schema.Option(
        display = "San Diego Padres",
        value = "135",
    ),
    schema.Option(
        display = "San Francisco Giants",
        value = "137",
    ),
    schema.Option(
        display = "Seattle Mariners",
        value = "136",
    ),
    schema.Option(
        display = "St. Louis Cardinals",
        value = "138",
    ),
    schema.Option(
        display = "Tampa Bay Rays",
        value = "139",
    ),
    schema.Option(
        display = "Texas Rangers",
        value = "140",
    ),
    schema.Option(
        display = "Toronto Blue Jays",
        value = "141",
    ),
    schema.Option(
        display = "Washington Nationals",
        value = "120",
    ),
]
