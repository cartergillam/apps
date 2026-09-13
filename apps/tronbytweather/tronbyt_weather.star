"""Weather v1 consumes normalized server snapshots; no provider networking."""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")

# BEGIN BUNDLED ICONS
SUN = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAkUlEQVR4nL1U2xGAIAwDzoncgandgZXqj3ql9BFONJ80CaQFUgJBrRK1ShGvoIYovjdEYnn8bBXzfnS1yOzmDyJJGk5wCa3Nh8jPTooZN+K8To/E0WC1RJ0yMhiLs/zabFbTUUj98hP+MxRPENXcyJpwtsev33LRitYLkesav8hiSngszlOTeXG9H3u2TaEhxwmzlHYejifZQwAAAABJRU5ErkJggg=="
PARTLY = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAr0lEQVR4nLWUuxWAIAxFwWNH6QA6gzvQO6q9OzCDDGBpHRvgkMgn+Hkd5nHJQ40QTIHRAEZDzddxgVz9D+TEKvllrijnDdVqMO+/baKmWwduY+7wZBdgNFCYHVfkmQYlvQ8dyIlDYTGUPksC9+NkvxgKRYsWUA7co2hPaa6Z0S4iXHzunloVIr+JG+u/Xy/1CbwCfqFpUPIzoE8YYtYGg6/TWnFfaXSVJnbryKsCY10TPmsIFtPHBQAAAABJRU5ErkJggg=="
CLOUD = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAWElEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDqQEUhLkZqWYgtXw4CoYCAADpuxvUYfMK4wAAAABJRU5ErkJggg=="
RAIN = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAbklEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDqQEUhLkZqWYgtXxIGPju/v/fd/d/jCRErDjVY5mqrmNgoLULqQEAxu9AILqDE5kAAAAASUVORK5CYII="
HEAVY_RAIN = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAdUlEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDqQEUhLkZqWYgtXxIGPju/v/fd/d/jCRErDjVY5mqrmNgoLULsbmAFHEGBgYGAK1yRiz9DXkqAAAAAElFTkSuQmCC"
SNOW = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAa0lEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDqQEUhLkZqWYgtXw4AOD///9Y0yOx4kzYJNEVkSpOVRdSHQAAYENLpraDaC4AAAAASUVORK5CYII="
HEAVY_SNOW = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAb0lEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDqQEUhLkZqWYgUT78//8/1pjHJU4fQKqr0MWZsEmiKyJVnKoupDoAAC85U55NnvIPAAAAAElFTkSuQmCC"
FOG = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAaUlEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDqQEUhLkZqWYgtXyIAeCmbjh2laJkE2ClTRsXUh0Mfi8DABl5I9aG8+N1AAAAAElFTkSuQmCC"
STORM = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAhUlEQVR4nGNgGHGAkViFD95+/Y/MVxDmxqqXiRzDcIkxMOBwIS7F2AC6S1E4pBiEy2CivEwMgDmGEV2AUkA1F9LeQFzpimwDiQHyDwPwyisIczMSbSAxhjEwEJn1/p9zxZkCGI12o5hB0IWkGMbAQMCFuAzDZhBRBmIzGJ9hRAN83qa5YQD9YzSbNNU9/QAAAABJRU5ErkJggg=="
UNKNOWN = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAUUlEQVR4nGNgGHGAEZvghmNX/xOjOcBKG0M/E6UuormBWL2MDyAHB128zEKMImIjiYFhMEUKtvBjYCDSy4QMQQaDx8vDHGw4dvU/sWlxBIYhAJgTE2X9WzjLAAAAAElFTkSuQmCC"
ICE = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAjklEQVR4nOWSOxKAIAxEWVtKL8BlLPGylnoYL2BpHQsHP5gMCLHyVbCEZTPEmN+B3MJ5Wem6d61l7zYlZpJmjJBQKuaIk942b4wk46yWcwhhEAu1qCX83lCaq2JDDVxroWao1WEaPxL5kR4jRMTrcb36L9/6Di8NHQ6d6JkK2M+5+mRCAOincx3MquGScmyJAkAFCtc8aAAAAABJRU5ErkJggg=="
MOON = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAcUlEQVR4nGNgGPLgwduv/x+8/fqfWPWM+AyCsRWEuXGqQwdM1DQMq4GkeI8oAykFKAZS6joMA6kB6G8gqcFAlAtJMZRoLxNrKIqBhBIxMYZiGEBqmKE7AsPLpGQ1bGqxhiExhuJSQ1AjehCQWlgMPgAAH94vX+UjVhAAAAAASUVORK5CYII="
NIGHT_PARTLY = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAeElEQVR4nGNgGPLgwduv/x+8/fqfWPWM+AyCsRWEuXGqQwdM1DQMq4GkeA8bYCFWIbpFuFyO4kJcrsMmjkst1jAkRiMuOYIGEmMhssEUG4hsMAMDUjqkNHZhgGoupL2BpOYIggZSAygIczNSzUCYDwl6k9gsN3QAACjnPec51o1AAAAAAElFTkSuQmCC"

# END BUNDLED ICONS
FONT = "CG-pixel-3x5-mono"
ICONS = {"clear": SUN, "mostly_clear": SUN, "partly_cloudy": PARTLY, "cloudy": CLOUD, "drizzle": RAIN, "rain": RAIN, "heavy_rain": HEAVY_RAIN, "freezing_rain": ICE, "snow": SNOW, "heavy_snow": HEAVY_SNOW, "fog": FOG, "thunderstorm": STORM}
LABELS = {"clear": "CLEAR", "mostly_clear": "FAIR", "partly_cloudy": "PARTLY CLOUDY", "cloudy": "CLOUDY", "fog": "FOG", "drizzle": "DRIZZLE", "rain": "RAIN", "heavy_rain": "HEAVY RAIN", "freezing_rain": "FREEZING RAIN", "snow": "SNOW", "heavy_snow": "HEAVY SNOW", "thunderstorm": "THUNDERSTORM"}

def main(config):
    raw = config.get("$provider_data", "")
    if raw == "":
        error = dictionary(json.decode(config.get("$provider_error", "{}")))
        return diagnostic("SET LOCATION" if error.get("code") == "weather_location_missing" else "UNAVAILABLE")
    weather = dictionary(json.decode(raw))
    current = dictionary(weather.get("current"))
    daily = weather.get("daily")
    daily = [dictionary(day) for day in daily[:3]] if type(daily) == "list" else []
    soon = dictionary(weather.get("soon"))
    stale = weather.get("stale", False) == True
    mode = config.get("mode", "auto")
    unit = "F" if config.get("units", "metric") == "imperial" else "C"
    pages = []
    if mode != "forecast" and type(current.get("temperature")) in ["int", "float"]:
        pages.append(current_page(current, daily, stale, unit))
    if mode == "auto" and soon and not stale:
        pages.append(soon_page(soon))
    if mode != "current" and daily:
        pages.append(forecast_page(daily, stale))
    if not pages:
        return diagnostic("UNAVAILABLE")
    return render.Root(delay = 5000, show_full_animation = True, child = render.Animation(children = pages))

def dictionary(value):
    return value if type(value) == "dict" else {}

def string(value, fallback):
    return value if type(value) == "string" and value else fallback

def temp(value):
    if type(value) not in ["int", "float"] or value < -999 or value > 999:
        return "--"

    # Round halves away from zero, including Canadian winter temperatures.
    return str(int(value + (0.5 if value >= 0 else -0.5)))

def text_box(value, width, height, color = "#ffffff", font = FONT):
    return render.Box(width = width, height = height, child = render.Text(content = value, color = color, font = font))

def icon(condition, size = 20, daytime = True):
    asset = ICONS.get(condition, UNKNOWN)
    if daytime == False and condition in ["clear", "mostly_clear", "partly_cloudy"]:
        asset = NIGHT_PARTLY if condition == "partly_cloudy" else MOON
    return render.Image(src = base64.decode(asset), width = size, height = size)

def high_low(day):
    value = "H" + temp(day.get("high")) + " L" + temp(day.get("low"))
    return value.replace(" ", "") if len(value) > 10 else value

def current_page(current, daily, stale, unit):
    condition = current.get("condition", "unknown")
    today = daily[0] if daily else {}
    number = temp(current.get("temperature")) + "°" + unit
    return render.Box(width = 64, height = 32, child = render.Column(children = [
        render.Row(children = [
            render.Box(width = 24, height = 25, child = icon(condition, daytime = current.get("daytime", True))),
            render.Box(width = 40, height = 25, child = render.Column(children = [
                text_box(number, 40, 13, font = "6x13"),
                text_box("FEEL " + temp(current.get("feelsLike")), 40, 6, "#9bc9e5"),
                text_box(high_low(today), 40, 6, "#ffffff"),
            ])),
        ]),
        text_box("STALE" if stale else LABELS.get(condition, "WEATHER"), 64, 7, "#ffce45" if stale else "#9bc9e5"),
    ]))

def soon_page(soon):
    kind = string(soon.get("kind"), "RAIN")
    condition = "snow" if kind == "SNOW" else ("freezing_rain" if kind == "ICE" else "rain")
    probability = soon.get("probability")
    heading = kind + (" %d%%" % int(probability * 100 + 0.5) if type(probability) in ["int", "float"] else "")
    return render.Box(width = 64, height = 32, child = render.Column(children = [
        render.Row(children = [render.Box(width = 24, height = 23, child = icon(condition)), text_box(heading, 40, 23)]),
        text_box(string(soon.get("timing"), "SOON")[:15], 64, 9, "#9bc9e5"),
    ]))

def forecast_page(daily, stale):
    cells = []
    for index in range(3):
        day = daily[index] if index < len(daily) else {}
        cells.append(render.Box(width = 21, height = 32, child = render.Column(children = [
            text_box("STALE" if stale and index == 0 else string(day.get("weekday"), "---")[:3].upper(), 21, 7, "#ffce45" if stale else "#9bc9e5"),
            render.Box(width = 21, height = 11, child = icon(day.get("condition", "unknown"), 10)),
            text_box(temp(day.get("high")), 21, 7),
            text_box(temp(day.get("low")), 21, 7, "#9bc9e5"),
        ])))
    return render.Box(width = 64, height = 32, child = render.Row(children = cells))

def diagnostic(message):
    return render.Root(child = render.Box(width = 64, height = 32, child = render.Column(children = [text_box("WEATHER", 64, 16, font = "tb-8"), text_box(message, 64, 16, "#ffce45")])))

def get_schema():
    return schema.Schema(version = "1", fields = [
        schema.Dropdown(id = "weather_contract", name = "Location", desc = "Uses the saved device location. Configure the device if missing.", icon = "gear", default = "1", options = [schema.Option(display = "Use Device Location", value = "1")]),
        schema.Dropdown(id = "units", name = "Temperature", desc = "Choose Celsius or Fahrenheit.", icon = "gear", default = "metric", options = [schema.Option(display = "Celsius", value = "metric"), schema.Option(display = "Fahrenheit", value = "imperial")]),
        schema.Dropdown(id = "mode", name = "Display", desc = "Auto includes meaningful precipitation and forecast pages.", icon = "gear", default = "auto", options = [schema.Option(display = "Auto", value = "auto"), schema.Option(display = "Current", value = "current"), schema.Option(display = "Forecast", value = "forecast")]),
    ])
