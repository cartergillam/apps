"""Local Weather renders sanitized OpenWeather data injected by the server."""

load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")

WEATHER_FIXTURE = '''{"location":{"latitude":43.07,"longitude":-79.95,"timezone":"America/Toronto","label":"Caledonia"},"current":{"timestamp":"2026-08-06T16:00:00Z","summary":"light rain","temperature":22.4,"feelsLike":23.1,"dailyHigh":25.0,"dailyLow":17.0,"precipitationProbability":0.65},"hourly":[{"timestamp":"2026-08-06T17:00:00Z","temperature":23.0,"summary":"cloudy","precipitationProbability":0.3},{"timestamp":"2026-08-06T18:00:00Z","temperature":24.0,"summary":"cloudy","precipitationProbability":0.2},{"timestamp":"2026-08-06T19:00:00Z","temperature":23.0,"summary":"clear","precipitationProbability":0.1}],"alerts":[],"providerUpdated":"2026-08-06T16:00:00Z","stale":false}'''
ALERT_FIXTURE = '''{"location":{"latitude":43.07,"longitude":-79.95,"timezone":"America/Toronto","label":"Caledonia"},"current":{"timestamp":"2026-08-06T16:00:00Z","summary":"thunderstorm","temperature":24.0,"feelsLike":26.0,"dailyHigh":26.0,"dailyLow":18.0,"precipitationProbability":0.9},"hourly":[],"alerts":[{"id":"test","title":"Severe thunderstorm warning","severity":"severe","startsAt":"2026-08-06T16:00:00Z","expiresAt":"2026-08-06T18:00:00Z"}],"providerUpdated":"2026-08-06T16:00:00Z","stale":false}'''

def main(config):
    scenario = config.get("_fixture_scenario", "")
    raw = ALERT_FIXTURE if scenario == "alert" else (WEATHER_FIXTURE if scenario == "weather" else config.get("$provider_data", ""))
    if raw == "":
        return status_frame(provider_error(config), "#ff9f0a")
    weather = json.decode(raw)
    pages = []
    current = weather["current"]
    unit = "°F" if config.get("units", "metric") == "imperial" else "°C"
    if config.bool("page_current"):
        pages.append(current_page(current, unit, weather.get("stale", False)))
    if config.bool("page_today"):
        pages.append(today_page(current, unit))
    if config.bool("page_hourly") and len(weather.get("hourly", [])) > 0:
        pages.append(hourly_page(weather["hourly"], unit))
    if config.bool("page_alerts") and len(weather.get("alerts", [])) > 0:
        pages.append(alert_page(weather["alerts"][0]))
    if len(pages) == 0:
        return status_frame("NO PAGES", "#ff9f0a")
    return render.Root(delay = 5000, show_full_animation = True, child = render.Animation(children = pages))

def current_page(current, unit, stale):
    return render.Column(
        expanded = True,
        main_align = "space_between",
        cross_align = "center",
        children = [
            render.Row(expanded = True, main_align = "space_between", children = [
                render.Text(content = "WEATHER", color = "#ffffff", font = "CG-pixel-3x5-mono"),
                render.Text(content = "STALE" if stale else "NOW", color = "#ffcc00" if stale else "#64d2ff", font = "CG-pixel-3x5-mono"),
            ]),
            render.Text(content = temperature(current.get("temperature", 0), unit), color = "#ffffff", font = "tom-thumb"),
            render.Text(content = current.get("summary", "")[:16].upper(), color = "#64d2ff", font = "CG-pixel-3x5-mono"),
        ],
    )

def today_page(current, unit):
    return render.Column(expanded = True, main_align = "space_around", cross_align = "center", children = [
        render.Text(content = "TODAY", color = "#ffffff", font = "tb-8"),
        render.Text(content = "H " + temperature(current.get("dailyHigh", 0), unit) + "  L " + temperature(current.get("dailyLow", 0), unit), color = "#ffffff", font = "CG-pixel-3x5-mono"),
        render.Text(content = "RAIN %d%%" % int(float(current.get("precipitationProbability", 0)) * 100), color = "#64d2ff", font = "CG-pixel-3x5-mono"),
    ])

def hourly_page(hourly, unit):
    cells = []
    for item in hourly[:3]:
        cells.append(render.Column(children = [
            render.Text(content = item["timestamp"][11:16], color = "#8e8e93", font = "CG-pixel-3x5-mono"),
            render.Text(content = temperature(item.get("temperature", 0), unit), color = "#ffffff", font = "CG-pixel-3x5-mono"),
        ]))
    return render.Column(expanded = True, main_align = "space_around", children = [
        render.Text(content = "NEXT HOURS", color = "#64d2ff", font = "CG-pixel-3x5-mono"),
        render.Row(expanded = True, main_align = "space_around", children = cells),
    ])

def alert_page(alert):
    return render.Column(expanded = True, main_align = "center", cross_align = "center", children = [
        render.Text(content = "! WEATHER !", color = "#ff453a", font = "tb-8"),
        render.Marquee(width = 64, child = render.Text(content = alert.get("title", "Weather alert"), color = "#ffffff", font = "CG-pixel-3x5-mono")),
    ])

def status_frame(message, color):
    return render.Root(child = render.Column(expanded = True, main_align = "center", cross_align = "center", children = [
        render.Text(content = "WEATHER", color = "#ffffff", font = "tb-8"),
        render.Text(content = message[:16], color = color, font = "CG-pixel-3x5-mono"),
    ]))

def provider_error(config):
    raw = config.get("$provider_error", "")
    if raw == "":
        return "SET UP KEY"
    code = json.decode(raw).get("code", "")
    if code == "provider_credential_missing":
        return "SET UP KEY"
    if code == "provider_rate_limited":
        return "RATE LIMITED"
    return "DATA UNAVAILABLE"

def temperature(value, unit):
    return "%d%s" % (int(float(value)), unit)

def get_schema():
    return schema.Schema(version = "1", fields = [
        schema.Text(id = "credential_id", name = "Managed OpenWeather credential", desc = "Logical server credential ID. The secret is never sent to this app.", icon = "gear", default = "weather-primary"),
        schema.Location(id = "custom_location", name = "Custom location", desc = "Leave empty to use the device location and timezone.", icon = "gear"),
        schema.Dropdown(id = "units", name = "Units", desc = "Canadian profiles default to metric.", icon = "gear", default = "metric", options = [
            schema.Option(display = "Celsius", value = "metric"),
            schema.Option(display = "Fahrenheit", value = "imperial"),
        ]),
        schema.Toggle(id = "page_current", name = "Current conditions", desc = "Show current conditions and feels-like temperature.", icon = "gear", default = True),
        schema.Toggle(id = "page_today", name = "Today's outlook", desc = "Show high, low and precipitation probability.", icon = "gear", default = True),
        schema.Toggle(id = "page_hourly", name = "Hourly outlook", desc = "Show the next few hours.", icon = "gear", default = True),
        schema.Toggle(id = "page_alerts", name = "Weather alerts", desc = "Show active alerts. No active alerts is normal.", icon = "gear", default = True),
    ])
