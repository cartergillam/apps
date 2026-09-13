"""Market Watch renders sanitized quote data injected by tronbyt-server."""

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")

OPEN_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false}]'''
CLOSED_QUOTE_FIXTURE = '''[{"symbol":"SHOP:TSX","displayName":"Shopify","price":156.32,"absoluteChange":-1.84,"percentageChange":-1.16,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-06T15:44:00Z","providerUpdated":"2026-08-06T15:44:00Z","delayed":false,"stale":false}]'''
DELAYED_QUOTE_FIXTURE = '''[{"symbol":"RY:TSX","displayName":"Royal Bank of Canada","price":182.14,"absoluteChange":0.36,"percentageChange":0.20,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-05T20:00:00Z","providerUpdated":"2026-08-05T20:00:00Z","delayed":true,"stale":false}]'''
STALE_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"closed","quoteTimestamp":"2026-08-06T14:00:00Z","providerUpdated":"2026-08-06T14:00:00Z","delayed":false,"stale":true}]'''
MULTI_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false},{"symbol":"SHOP:TSX","displayName":"Shopify","price":156.32,"absoluteChange":-1.84,"percentageChange":-1.16,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-06T15:44:00Z","providerUpdated":"2026-08-06T15:44:00Z","delayed":false,"stale":false},{"symbol":"MSFT","displayName":"Microsoft","price":481.02,"absoluteChange":-3.11,"percentageChange":-0.64,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false}]'''

FONT = "CG-pixel-3x5-mono"
TICKER_DELAY = 55

def main(config):
    scenario = config.get("_fixture_scenario", "")
    raw = fixture_data(scenario) or config.get("$provider_data", "")
    if raw == "":
        return status_frame(fixture_error(scenario) or provider_error(config, "SETUP REQUIRED"), "#ffb454")
    decoded = json.decode(raw)
    quotes = [q for q in decoded if type(q) == "dict"][:10] if type(decoded) == "list" else []
    if len(quotes) == 0:
        return status_frame("NO QUOTES", "#ffb454")
    if config.get("display_mode", "focus") == "ticker":
        return ticker(quotes, config)

    # Legacy one/two mode values safely open in the detailed Focus design.
    return render.Root(delay = int(config.get("symbol_duration", "5")) * 1000, show_full_animation = True, child = render.Animation(children = [focus(q, config) for q in quotes]))

def focus(quote, config):
    return quote_card(quote, config)

def card_text(value, width, height, color, font = FONT):
    # Box centers its child. An expanded start-aligned Row pins the text X.
    return render.Box(width = width, height = height, child = render.Row(
        expanded = True,
        main_align = "start",
        children = [render.Text(content = value, font = font, color = color)],
    ))

def quote_card(quote, config):
    error = quote.get("errorCode", "")
    error_words = quote_error(error).split(" ") if error else []
    value = price(number(quote.get("price")))
    return render.Box(width = 64, height = 32, child = render.Row(main_align = "start", children = [
        render.Box(width = 20, height = 32, child = render.Column(children = [
            render.Box(width = 20, height = 24, child = company_mark(quote)),
            render.Box(width = 20, height = 8),
        ])),
        render.Box(width = 44, height = 32, child = render.Column(children = [
            card_text(short(display_symbol(text(quote.get("symbol"), "?")), 10), 44, 8, "#ffffff"),
            card_text(short(error_words[0], 10) if error else short(value, 10), 44, 10, "#ffb454" if error else "#ffffff", FONT if error or len(value) > 7 else "tb-8"),
            card_text(short(" ".join(error_words[1:]), 10) if error else short(movement(quote, config), 10), 44, 7, "#ffb454" if error else movement_color(quote)),
            render.Row(children = [
                card_text(text(quote.get("currency"), "")[:3], 16, 7, "#9bb5c8"),
                card_text("" if error else quote_status(quote), 28, 7, status_color(quote)),
            ]),
        ])),
    ]))

def ticker(quotes, config):
    # Bounded strips advance by their measured item width, including the same
    # five-pixel gap at every boundary. Repeat following items until 64 pixels
    # are available, even for a one-symbol loop narrower than the viewport.
    measured = [ticker_item(q, config) for q in quotes]
    items = [item[0] for item in measured]
    widths = [item[1] for item in measured]
    if config.get("_fixture_measure", "") == "true":
        print(json.encode(widths))
    strips = []
    for index in range(len(items)):
        children = [items[index]]
        following_width = 0
        for step in range(1, 5):
            if following_width >= 64:
                break
            following = (index + step) % len(items)
            children.append(items[following])
            following_width += widths[following]
        strips.append(render.Marquee(
            width = 64,
            offset_start = 0,
            offset_end = following_width + 65,
            child = render.Row(children = children),
        ))
    return render.Root(delay = TICKER_DELAY, show_full_animation = True, child = render.Sequence(children = strips))

def ticker_item(quote, config):
    error = quote.get("errorCode", "")
    symbol = short(display_symbol(text(quote.get("symbol"), "?")), 10)
    value = price(number(quote.get("price")))
    compact_errors = {"provider_entitlement_required": "PLAN", "provider_credential_invalid": "KEY", "invalid_symbol": "BAD SYMBOL", "provider_rate_limited": "LIMITED", "provider_response_invalid": "BAD DATA"}
    fields = [
        render.Text(content = symbol, font = FONT, color = "#ffffff"),
        render.Text(content = compact_errors.get(error, "ERROR") if error else short(value, 10), font = FONT if error or len(value) > 7 else "tb-8", color = "#ffb454" if error else "#ffffff"),
        render.Text(content = "" if error else short(movement(quote, config), 10), font = FONT, color = movement_color(quote)),
        render.Text(content = text(quote.get("currency"), "")[:3], font = FONT, color = "#9bb5c8"),
    ]
    width = max([field.size()[0] for field in fields])
    heights = [8, 10, 7, 7]
    rows = [render.Box(width = width, height = heights[i], child = render.Row(expanded = True, main_align = "start", children = [fields[i]])) for i in range(4)]
    state = quote_status(quote)
    visible_state = state if state in ["STALE", "EOD", "DELAY"] else ""
    mark = render.Column(children = [
        render.Box(width = 20, height = 24, child = company_mark(quote)),
        render.Box(width = 20, height = 8, child = render.Text(content = visible_state, font = FONT, color = status_color(quote))),
    ])
    return (render.Box(width = 22 + width + 5, height = 32, child = render.Row(children = [
        render.Box(width = 20, height = 32, child = mark),
        render.Box(width = 2, height = 32),
        render.Box(width = width, height = 32, child = render.Column(children = rows)),
        render.Box(width = 5, height = 32),
    ])), 22 + width + 5)

def quote_error(code):
    return {
        "provider_credential_invalid": "INVALID KEY",
        "provider_entitlement_required": "PLAN REQUIRED",
        "invalid_symbol": "BAD SYMBOL",
        "listing_mismatch": "CHECK LISTING",
        "provider_rate_limited": "RATE LIMITED",
        "provider_response_invalid": "BAD RESPONSE",
    }.get(code, "PROVIDER ERROR")

def company_mark(quote):
    logo = text(quote.get("logoData"), "")
    if logo != "":
        return render.Box(width = 18, height = 18, child = render.Image(src = base64.decode(logo), width = 18, height = 18))
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
        return "MAX 10 SYMBOLS"
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
        "closed": "",
    }.get(value, "")

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
    if scenario in ["density_short", "density_two", "density_five", "density_ten"]:
        apple = json.decode(fixture_data("aapl"))[0]
        microsoft = json.decode(fixture_data("msft"))[0]
        short_quote = dict(apple)
        short_quote.update({"price": 9.25, "absoluteChange": 0.1, "percentageChange": 0.1})
        if scenario == "density_short":
            return json.encode([short_quote])
        if scenario == "density_two":
            return json.encode([apple, microsoft])
        nvidia = dict(short_quote)
        nvidia.update({"symbol": "NVDA", "price": 27.33, "logoData": ""})
        shop = dict(short_quote)
        shop.update({"symbol": "SHOP", "price": 119.2, "currency": "CAD", "logoData": ""})
        five = [apple, microsoft, nvidia, shop, json.decode(fixture_data("canadian_plan"))[0]]
        if scenario == "density_five":
            return json.encode(five)
        extra = []
        for symbol in ["BRK.B", "GOOG", "AMZN", "RY", "META"]:
            quote = dict(short_quote)
            quote.update({"symbol": symbol, "logoData": ""})
            extra.append(quote)
        return json.encode(five + extra)
    if scenario in ["layout_nasdaq", "layout_nyse", "layout_tsx", "layout_cad", "layout_long", "layout_missing", "layout_plan", "layout_mixed"]:
        apple = json.decode(fixture_data("aapl"))[0]
        if scenario == "layout_nyse":
            apple.update({"exchange": "NYSE", "mic": "XNYS"})
        if scenario == "layout_tsx":
            apple.update({"exchange": "Toronto Stock Exchange", "mic": "XTSE"})
        if scenario == "layout_cad":
            apple["currency"] = "CAD"
        if scenario == "layout_long":
            apple["symbol"] = "BRK.B"
        if scenario == "layout_missing":
            apple["logoData"] = ""
        if scenario == "layout_plan":
            apple.update({"symbol": "PLZ.UN", "exchange": "TSX", "mic": "XTSE", "currency": "CAD", "errorCode": "provider_entitlement_required"})
        if scenario == "layout_mixed":
            return json.encode([apple, json.decode(fixture_data("msft"))[0], json.decode(fixture_data("canadian_plan"))[0]])
        return json.encode([apple])
    if scenario in ["aapl", "five", "two", "unchanged", "long", "same_company", "logo_absent", "mixed_plan", "aapl_closed", "aapl_stale", "msft", "five_open", "five_closed", "ten", "dotted", "canadian_plan"]:
        apple = json.decode(OPEN_QUOTE_FIXTURE)[0]
        apple["logoData"] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABFElEQVR4nKyTPS8EURSG34NW4yNEo1QpViIqFBJBKdH4CUrxD9R+gUQiau1G66PQiKg0tpAlIlH5aBQeudltdnfuvXMy85Qz9z7nPefMDKlmXEJgBXgCDipXBhaBLzps1iG86MqugOGqslHgGWgCY6mzFhHMSdqVNCPpVlJT0rikWUnrkiYl3Uk6NbOPXJod4Ide3oBHBmkBjZRsHvgsuBjjHVhKCU8cssBWrt2WQ/YADOyg/8OeSFbs5cXMyAl/HcLpoof9wrZD2ACWc8IbhzDM7xhYiJ4AVoE/56bb0YRmdinp2pEycJ58C6w50oX/eypbEjgqKdwu1QMwApx1L90De8AGcAi8At/AfumhVOE/AAD//0hOz+c8BA+LAAAAAElFTkSuQmCC"
        cad = json.decode(CLOSED_QUOTE_FIXTURE)[0]
        usd = dict(cad)
        usd.update({"symbol": "SHOP", "mic": "XNYS", "exchange": "NYSE", "currency": "USD", "price": 119.22})
        if scenario in ["dotted", "canadian_plan"]:
            apple.update({"symbol": "PLZ.UN", "mic": "XTSE", "exchange": "TSX", "currency": "CAD", "logoData": ""})
            if scenario == "canadian_plan":
                apple["errorCode"] = "provider_entitlement_required"
            return json.encode([apple])
        if scenario in ["aapl_closed", "aapl_stale"]:
            apple["marketStatus"] = "closed"
            apple["stale"] = scenario == "aapl_stale"
            return json.encode([apple])
        if scenario == "msft":
            apple["symbol"] = "MSFT"
            apple["logoData"] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAA0klEQVR4nGJioDJgARGfApT+o0swQvG/nz8t+bY/PQESq97GYMHKynAcrBhDBwNDoxsDI9VdOAINBEcKIxYJbGIMrBAJxv8MDP+xKsBjIFgcpwTEUJwGgpIGDq0MPx4+vQJjv3/PcEVQkAGi9jcuHVQGtIkUhiVvLXCq+Pj3CkO22BcQ8/8qBh4GHgYdXEoZvRhOQAxkZDmOKQsl+MFhBs56YMNYGSBqsUcKI8RAbLL/8UQlDmEGuJf/Y1HByIA9sf3Hb+jgz3qD30CqA0AAAAD//8r2MOGLRuDeAAAAAElFTkSuQmCC"
            return json.encode([apple])
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
        five = [apple, nvidia, cad, usd, eod]
        if scenario in ["five_open", "five_closed", "ten", "dotted", "canadian_plan"]:
            for quote in five:
                quote.update({"marketStatus": "open" if scenario == "five_open" else "closed", "eod": False, "delayed": False})
        if scenario == "ten":
            extra = []
            for symbol in ["MSFT", "AMZN", "GOOG", "META", "PLZ.UN"]:
                quote = dict(apple)
                quote.update({"symbol": symbol, "logoData": ""})
                extra.append(quote)
            return json.encode(five + extra)
        return json.encode(five)
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
            schema.Text(id = "credential_id", name = "Market credential override", desc = "Normally uses the device assignment. Owners may select a logical override; secrets remain on the server.", icon = "gear", default = ""),
            schema.Text(id = "watchlist", name = "Watchlist listings", desc = "Managed by the mobile stock picker. Leave empty to use legacy symbols.", icon = "star", default = ""),
            schema.Text(id = "symbols", name = "Symbols", desc = "One to ten unique comma-separated symbols, such as AAPL or SHOP:TSX. Availability depends on your provider plan.", icon = "gear", default = "AAPL"),
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
