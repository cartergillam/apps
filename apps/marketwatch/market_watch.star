"""Market Watch renders sanitized quote data injected by tronbyt-server."""

load("encoding/json.star", "json")
load("encoding/base64.star", "base64")
load("render.star", "render")
load("schema.star", "schema")

OPEN_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false}]'''
CLOSED_QUOTE_FIXTURE = '''[{"symbol":"SHOP:TSX","displayName":"Shopify","price":156.32,"absoluteChange":-1.84,"percentageChange":-1.16,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-06T15:44:00Z","providerUpdated":"2026-08-06T15:44:00Z","delayed":false,"stale":false}]'''
DELAYED_QUOTE_FIXTURE = '''[{"symbol":"RY:TSX","displayName":"Royal Bank of Canada","price":182.14,"absoluteChange":0.36,"percentageChange":0.20,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-05T20:00:00Z","providerUpdated":"2026-08-05T20:00:00Z","delayed":true,"stale":false}]'''
STALE_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"closed","quoteTimestamp":"2026-08-06T14:00:00Z","providerUpdated":"2026-08-06T14:00:00Z","delayed":false,"stale":true}]'''
MULTI_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false},{"symbol":"SHOP:TSX","displayName":"Shopify","price":156.32,"absoluteChange":-1.84,"percentageChange":-1.16,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-06T15:44:00Z","providerUpdated":"2026-08-06T15:44:00Z","delayed":false,"stale":false},{"symbol":"MSFT","displayName":"Microsoft","price":481.02,"absoluteChange":-3.11,"percentageChange":-0.64,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false}]'''

FONT = "CG-pixel-3x5-mono"
TICKER_WIDTH = 96
TICKER_DELAY = 40

def main(config):
    scenario = config.get("_fixture_scenario", "")
    raw = fixture_data(scenario) or config.get("$provider_data", "")
    if raw == "":
        return status_frame(fixture_error(scenario) or provider_error(config, "SETUP REQUIRED"), "#ffb454")
    decoded = json.decode(raw)
    quotes = [q for q in decoded if type(q) == "dict"][:5] if type(decoded) == "list" else []
    if len(quotes) == 0:
        return status_frame("NO QUOTES", "#ffb454")
    if config.get("display_mode", "focus") == "ticker":
        return ticker(quotes, config)
    # Legacy one/two mode values safely open in the detailed Focus design.
    return render.Root(delay = int(config.get("symbol_duration", "5")) * 1000, show_full_animation = True, child = render.Animation(children = [focus(q, config) for q in quotes]))

def focus(quote, config):
    error = quote.get("errorCode", "")
    symbol = display_symbol(text(quote.get("symbol"), "?"))
    return render.Column(children = [
        render.Row(children = [
            render.Box(width = 38, height = 7, child = render.Text(content = short(symbol, 9), font = FONT, color = "#ffffff")),
            render.Box(width = 26, height = 7, child = render.Text(content = "PLAN" if error == "provider_entitlement_required" else quote_status(quote), font = FONT, color = status_color(quote))),
        ]),
        render.Row(children = [
            render.Box(width = 20, height = 18, child = company_mark(quote)),
            render.Box(width = 44, height = 18, child = render.Column(children = [
                render.Box(width = 44, height = 11, child = render.Text(content = "UNAVAILABLE" if error else price(number(quote.get("price"))), font = FONT if error else "tb-8", color = "#ffffff")),
                render.Box(width = 44, height = 7, child = render.Text(content = "PLAN REQD" if error == "provider_entitlement_required" else ("CHECK LIST" if error else movement(quote, config)), font = FONT, color = "#ffb454" if error else movement_color(quote))),
            ])),
        ]),
        render.Box(width = 64, height = 7, color = "#0c1925", child = render.Text(content = listing_label(quote)[:16], font = FONT, color = "#9bb5c8")),
    ])

def ticker(quotes, config):
    # One pixel every 40 ms. A duplicate first card supplies the wraparound
    # pixels; offsets stop exactly one cycle later, before any blank/reset.
    cards = [ticker_card(q, config) for q in quotes]
    cards.append(ticker_card(quotes[0], config))
    return render.Root(delay = TICKER_DELAY, show_full_animation = True, child = render.Marquee(
        width = 64,
        offset_start = 0,
        offset_end = TICKER_WIDTH + 65,
        child = render.Row(children = cards),
    ))

def ticker_card(quote, config):
    error = quote.get("errorCode", "")
    return render.Row(children = [
        render.Box(width = 20, height = 32, child = render.Column(children = [
            render.Box(width = 20, height = 24, child = company_mark(quote)),
            render.Box(width = 20, height = 8, child = render.Text(content = text(quote.get("currency"), "---")[:3], font = FONT, color = "#9bb5c8")),
        ])),
        render.Column(children = [
            render.Box(width = 68, height = 8, child = render.Text(content = short(display_symbol(text(quote.get("symbol"), "?")), 15), font = FONT, color = "#ffffff")),
            render.Box(width = 68, height = 10, child = render.Text(content = "PLAN REQUIRED" if error == "provider_entitlement_required" else ("CHECK LISTING" if error else price(number(quote.get("price")))), font = FONT if error else "tb-8", color = "#ffb454" if error else "#ffffff")),
            render.Box(width = 68, height = 7, child = render.Text(content = "" if error else movement(quote, config), font = FONT, color = movement_color(quote))),
            render.Box(width = 68, height = 7, color = "#0c1925", child = render.Text(content = (venue(quote) + " " + quote_status(quote))[:16], font = FONT, color = status_color(quote))),
        ]),
        render.Box(width = 8, height = 32),
    ])

def company_mark(quote):
    logo = text(quote.get("logoData"), "")
    if logo != "":
        return render.Box(width = 18, height = 18, color = "#e5e9ee", child = render.Image(src = base64.decode(logo), width = 18, height = 18))
    return render.Box(width = 18, height = 18, color = "#15324a", child = render.Text(content = display_symbol(text(quote.get("symbol"), "?"))[:3], font = FONT, color = "#b5dfff"))

def movement(quote, config):
    absolute = config.get("movement_format", "") == "value"
    if config.get("movement_format", "auto") == "auto":
        absolute = config.bool("show_absolute_change", True) and not config.bool("show_percentage_change", True)
    value = number(quote.get("absoluteChange" if absolute else "percentageChange"))
    return signed(value) + ("" if absolute else "%")

def movement_color(quote):
    value = number(quote.get("absoluteChange"))
    return "#4be6a0" if value > 0 else ("#ff657a" if value < 0 else "#aab8c5")

def venue(quote):
    mic = text(quote.get("mic"), "")
    return {"XTSE": "TSX", "XNAS": "NASDAQ", "XNYS": "NYSE", "ARCX": "ARCA"}.get(mic, short(text(quote.get("exchange"), mic or "AUTO"), 8))

def listing_label(quote):
    return text(quote.get("currency"), "---") + " " + venue(quote)

def short(value, length):
    return value if len(value) <= length else value[:length - 1] + "~"

def text(value, fallback):
    return value if type(value) == "string" and value else fallback

def number(value):
    return value if type(value) in ["int", "float"] else 0

def status_frame(message, color):
    return render.Root(child = render.Column(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = [
            render.Text(content = "MARKET", color = "#ffffff", font = "tb-8"),
            render.Text(content = message[:14], color = color, font = "CG-pixel-3x5-mono"),
        ],
    ))

def provider_error(config, fallback):
    raw = config.get("$provider_error", "")
    if raw == "":
        return fallback
    code = json.decode(raw).get("code", "")
    if code == "invalid_symbol":
        return "BAD SYMBOL"
    if code == "market_symbol_limit":
        return "MAX 5 SYMBOLS"
    if code == "provider_rate_limited":
        return "RATE LIMITED"
    if code in ["provider_credential_missing", "provider_setup_required"]:
        return "SETUP REQUIRED"
    if code == "provider_credential_invalid":
        return "INVALID KEY"
    if code == "provider_entitlement_required":
        return "PLAN REQUIRED"
    if code == "provider_response_invalid":
        return "BAD RESPONSE"
    return "PROVIDER ERROR"

def display_symbol(value):
    # Exchange qualification remains in the provider request. The compact
    # ticker is the readable identity on a 64-pixel physical display.
    return value.split(":")[0]

def price(value):
    value = float(value)
    if value >= 1000000:
        return decimal2(value / 1000000) + "M"
    if value >= 10000:
        return decimal2(value / 1000) + "K"
    return decimal2(value)

def signed(value):
    return ("+" if value >= 0 else "") + decimal2(value)

def decimal2(value):
    negative = value < 0
    absolute = -value if negative else value
    rounded = int(absolute * 100 + 0.5)
    whole = rounded // 100
    cents = rounded % 100
    result = str(whole) + "." + ("0" if cents < 10 else "") + str(cents)
    return "-" + result if negative else result

def market_status(value):
    return {
        "open": "OPEN",
        "closed": "CLOSED",
    }.get(value, "QUOTE")

def quote_status(quote):
    if quote.get("stale", False):
        return "STALE"
    if quote.get("eod", False):
        return "EOD"
    if quote.get("delayed", False):
        return "DELAY"
    return market_status(quote.get("marketStatus", "unknown"))

def quote_badge(quote):
    return {
        "OPEN": "O ",
        "CLOSED": "C ",
        "EOD": "E ",
        "STALE": "S ",
    }.get(quote_status(quote), "? ")

def status_color(quote):
    status = quote_status(quote)
    if status in ["STALE", "EOD", "DELAY"]:
        return "#ffcc00"
    if status == "OPEN":
        return "#30d158"
    return "#8e8e93"

def fixture_data(scenario):
    if scenario in ["aapl", "five", "two", "unchanged", "long", "same_company", "logo_absent", "mixed_plan"]:
        apple = json.decode(OPEN_QUOTE_FIXTURE)[0]
        apple["logoData"] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAIAAAAC64paAAABnUlEQVR4nJTTz6sBURQH8PPGpaFZ2snKAk1sWCgLJUpZqalZUOQvsPQ3UErKf2BlYaXZ2FhIykrZWFnYKErzg4tyX94P5s7oue/s7sz305w7ncMRhlosFs1m83A4WJ7DW9lqtVwul9fr/Tfu9/vwVdVq1f72L3y73WKxGAAEg8HtdmsPcGArVVUxxgBwOp0IIaVSaTgc8jyv67ol+XH/+m8pitJut5fLpdvtTqVSkiQRQiaTiaIo6/VaEIRkMlmv1yORyA949NBoNOxdcJy1NZ7nZ7MZdefxeGyXL6tQKOz3ewpLksQiQ6GQYRjUDzMMYz6fs2BZlj0ez/NSAKDruqZpLNjv95uPd4wQcjgcLHiz2VBnQsjlchFFkQWLoogxtk5YuVxmwQBQqVTO5zOFB4MBIwaAbDZ7vV6f45nL5cLhMCP2+XwIITBPWK/XY5GCIKxWqxdbVSwW3+JOp/N6JTVNy2Qy3yGEUDQaTafTgUDgIWu1mjlPbRUAHI/Hbre72+3y+XwikXA6naqqjkaj6XQaj8dlWTaHPwMAAP//yEnZbRT/mzYAAAAASUVORK5CYII="
        cad = json.decode(CLOSED_QUOTE_FIXTURE)[0]
        usd = dict(cad)
        usd.update({"symbol": "SHOP", "mic": "XNYS", "exchange": "NYSE", "currency": "USD", "price": 119.22})
        if scenario == "aapl":
            return json.encode([apple])
        if scenario == "two":
            return json.encode([apple, cad])
        if scenario == "same_company":
            return json.encode([cad, usd])
        if scenario == "logo_absent":
            return OPEN_QUOTE_FIXTURE
        if scenario == "long":
            apple.update({"symbol": "VERYLONGTICKER1", "displayName": "A very long company name", "price": 1234567.89})
            return json.encode([apple])
        if scenario == "unchanged":
            apple.update({"absoluteChange": 0, "percentageChange": 0})
            return json.encode([apple])
        if scenario == "mixed_plan":
            cad["errorCode"] = "provider_entitlement_required"
            return json.encode([apple, cad])
        nvidia = dict(apple)
        nvidia.update({"symbol": "NVDA", "logoData": "", "price": 184.52, "absoluteChange": -1.12, "percentageChange": -0.6})
        eod = json.decode(DELAYED_QUOTE_FIXTURE)[0]
        eod["eod"] = True
        return json.encode([apple, nvidia, cad, usd, eod])
    return {
        "open": OPEN_QUOTE_FIXTURE,
        "closed": CLOSED_QUOTE_FIXTURE,
        "tsx": CLOSED_QUOTE_FIXTURE,
        "delayed": DELAYED_QUOTE_FIXTURE,
        "eod": DELAYED_QUOTE_FIXTURE.replace('"delayed":true', '"eod":true,"delayed":true'),
        "stale": STALE_QUOTE_FIXTURE,
        "multiple": MULTI_QUOTE_FIXTURE,
    }.get(scenario, "")

def fixture_error(scenario):
    return {
        "invalid_symbol": "BAD SYMBOL",
        "rate_limited": "RATE LIMITED",
        "setup": "SETUP REQUIRED",
        "invalid_key": "INVALID KEY",
        "plan_required": "PLAN REQUIRED",
        "provider_error": "PROVIDER ERROR",
    }.get(scenario, "")

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "credential_id", name = "Managed market credential", desc = "Logical server credential ID. The secret is never sent to this app.", icon = "gear", default = "market-primary"),
            schema.Text(id = "watchlist", name = "Watchlist listings", desc = "Managed by the mobile stock picker. Leave empty to use legacy symbols.", icon = "star", default = ""),
            schema.Text(id = "symbols", name = "Symbols", desc = "One to five unique comma-separated symbols, such as AAPL or SHOP:TSX. Availability depends on your provider plan.", icon = "gear", default = "AAPL"),
            schema.Dropdown(id = "display_mode", name = "Display mode", desc = "Focus on one stock or scroll the whole watchlist continuously.", icon = "gear", default = "focus", options = [
                schema.Option(display = "Focus", value = "focus"),
                schema.Option(display = "Ticker", value = "ticker"),
                schema.Option(display = "Focus (legacy)", value = "one"),
                schema.Option(display = "Focus (legacy split)", value = "two"),
            ]),
            schema.Dropdown(id = "symbol_duration", name = "Per-symbol duration", desc = "Seconds per page.", icon = "gear", default = "5", options = [
                schema.Option(display = "3 seconds", value = "3"),
                schema.Option(display = "5 seconds", value = "5"),
                schema.Option(display = "8 seconds", value = "8"),
            ]),
            schema.Dropdown(id = "movement_format", name = "Movement", desc = "Show the percentage or price change in the listing currency.", icon = "gear", default = "auto", options = [schema.Option(display = "Existing preference", value = "auto"), schema.Option(display = "Percentage", value = "percent"), schema.Option(display = "Price change", value = "value")]),
            schema.Toggle(id = "show_absolute_change", name = "Absolute change", desc = "Show the price change.", icon = "gear", default = True),
            schema.Toggle(id = "show_percentage_change", name = "Percentage change", desc = "Show the percentage change.", icon = "gear", default = True),
        ],
    )
