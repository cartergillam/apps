"""Market Watch renders sanitized quote data injected by tronbyt-server."""

load("encoding/json.star", "json")
load("render.star", "render")
load("schema.star", "schema")

OPEN_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false}]'''
CLOSED_QUOTE_FIXTURE = '''[{"symbol":"SHOP:TSX","displayName":"Shopify","price":156.32,"absoluteChange":-1.84,"percentageChange":-1.16,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-06T15:44:00Z","providerUpdated":"2026-08-06T15:44:00Z","delayed":false,"stale":false}]'''
DELAYED_QUOTE_FIXTURE = '''[{"symbol":"RY:TSX","displayName":"Royal Bank of Canada","price":182.14,"absoluteChange":0.36,"percentageChange":0.20,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-05T20:00:00Z","providerUpdated":"2026-08-05T20:00:00Z","delayed":true,"stale":false}]'''
STALE_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"closed","quoteTimestamp":"2026-08-06T14:00:00Z","providerUpdated":"2026-08-06T14:00:00Z","delayed":false,"stale":true}]'''
MULTI_QUOTE_FIXTURE = '''[{"symbol":"AAPL","displayName":"Apple Inc","price":212.48,"absoluteChange":2.15,"percentageChange":1.02,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false},{"symbol":"SHOP:TSX","displayName":"Shopify","price":156.32,"absoluteChange":-1.84,"percentageChange":-1.16,"exchange":"Toronto Stock Exchange","mic":"XTSE","currency":"CAD","marketStatus":"closed","quoteTimestamp":"2026-08-06T15:44:00Z","providerUpdated":"2026-08-06T15:44:00Z","delayed":false,"stale":false},{"symbol":"MSFT","displayName":"Microsoft","price":481.02,"absoluteChange":-3.11,"percentageChange":-0.64,"exchange":"NASDAQ","mic":"XNAS","currency":"USD","marketStatus":"open","quoteTimestamp":"2026-08-06T15:45:00Z","providerUpdated":"2026-08-06T15:45:00Z","delayed":false,"stale":false}]'''

def main(config):
    scenario = config.get("_fixture_scenario", "")
    raw = fixture_data(scenario)
    if raw == "":
        raw = config.get("$provider_data", "")
    if raw == "":
        return status_frame(fixture_error(scenario) or provider_error(config, "SET UP KEY"), "#ff9f0a")
    quotes = json.decode(raw)
    if len(quotes) == 0:
        return status_frame("NO QUOTES", "#ff9f0a")
    mode = config.get("display_mode", "one")
    duration = int(config.get("symbol_duration", "5")) * 1000
    pages = []
    if mode == "two":
        for i, _ in enumerate(quotes):
            if i % 2 == 0:
                pages.append(two_quote_page(quotes[i:i + 2]))
    else:
        for quote in quotes:
            pages.append(one_quote_page(quote, config))
    return render.Root(
        delay = duration,
        show_full_animation = True,
        child = render.Animation(children = pages),
    )

def one_quote_page(quote, config):
    change = float(quote.get("absoluteChange", 0))
    color = "#30d158" if change >= 0 else "#ff453a"
    status = quote_status(quote)
    currency = quote.get("currency", "")[:3]
    status_label = status if currency == "" else status + " " + currency
    change_parts = []
    if config.bool("show_absolute_change"):
        change_parts.append(signed(change))
    if config.bool("show_percentage_change"):
        change_parts.append(signed(float(quote.get("percentageChange", 0))) + "%")
    return render.Column(
        expanded = True,
        main_align = "space_between",
        cross_align = "center",
        children = [
            render.Row(
                expanded = True,
                main_align = "space_between",
                children = [
                    render.Text(content = quote.get("symbol", "?")[:9], color = "#ffffff", font = "tb-8"),
                    render.Text(content = status_label[:10], color = status_color(quote), font = "CG-pixel-3x5-mono"),
                ],
            ),
            render.Text(content = price(quote.get("price", 0)), color = "#ffffff", font = "tom-thumb"),
            render.Text(content = " ".join(change_parts) if len(change_parts) > 0 else "--", color = color, font = "CG-pixel-3x5-mono"),
        ],
    )

def two_quote_page(quotes):
    rows = []
    for quote in quotes:
        change = float(quote.get("percentageChange", 0))
        rows.append(render.Row(
            expanded = True,
            main_align = "space_between",
            children = [
                render.Text(content = quote_badge(quote) + quote.get("symbol", "?")[:6], color = status_color(quote), font = "CG-pixel-3x5-mono"),
                render.Text(content = price(quote.get("price", 0)), color = "#ffffff", font = "CG-pixel-3x5-mono"),
                render.Text(content = signed(change) + "%", color = "#30d158" if change >= 0 else "#ff453a", font = "CG-pixel-3x5-mono"),
            ],
        ))
    if len(rows) == 1:
        rows.append(render.Box(height = 10))
    return render.Column(expanded = True, main_align = "space_around", children = rows)

def status_frame(message, color):
    return render.Root(child = render.Column(
        expanded = True,
        main_align = "center",
        cross_align = "center",
        children = [
            render.Text(content = "MARKET", color = "#ffffff", font = "tb-8"),
            render.Text(content = message[:16], color = color, font = "CG-pixel-3x5-mono"),
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
    if code == "provider_credential_missing":
        return "SET UP KEY"
    return "DATA UNAVAILABLE"

def price(value):
    value = float(value)
    if value >= 1000:
        return str(int(value))
    return decimal2(value)

def signed(value):
    return ("+" if value >= 0 else "") + decimal2(value)

def decimal2(value):
    negative = value < 0
    absolute = -value if negative else value
    whole = int(absolute)
    cents = int((absolute - whole) * 100)
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
    if quote.get("delayed", False):
        return "EOD"
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
    if status == "STALE" or status == "EOD":
        return "#ffcc00"
    if status == "OPEN":
        return "#30d158"
    return "#8e8e93"

def fixture_data(scenario):
    return {
        "open": OPEN_QUOTE_FIXTURE,
        "closed": CLOSED_QUOTE_FIXTURE,
        "tsx": CLOSED_QUOTE_FIXTURE,
        "delayed": DELAYED_QUOTE_FIXTURE,
        "stale": STALE_QUOTE_FIXTURE,
        "multiple": MULTI_QUOTE_FIXTURE,
    }.get(scenario, "")

def fixture_error(scenario):
    return {
        "invalid_symbol": "BAD SYMBOL",
        "rate_limited": "RATE LIMITED",
        "setup": "SET UP KEY",
    }.get(scenario, "")

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "credential_id", name = "Managed market credential", desc = "Logical server credential ID. The secret is never sent to this app.", icon = "gear", default = "market-primary"),
            schema.Text(id = "symbols", name = "Symbols", desc = "One to five unique comma-separated symbols, such as AAPL or SHOP:TSX. Availability depends on your provider plan.", icon = "gear", default = "AAPL,SHOP:TSX"),
            schema.Dropdown(id = "display_mode", name = "Display mode", desc = "Use readable pages rather than squeezing every symbol into one frame.", icon = "gear", default = "one", options = [
                schema.Option(display = "One stock per frame", value = "one"),
                schema.Option(display = "Two-stock split", value = "two"),
            ]),
            schema.Dropdown(id = "symbol_duration", name = "Per-symbol duration", desc = "Seconds per page.", icon = "gear", default = "5", options = [
                schema.Option(display = "3 seconds", value = "3"),
                schema.Option(display = "5 seconds", value = "5"),
                schema.Option(display = "8 seconds", value = "8"),
            ]),
            schema.Toggle(id = "show_absolute_change", name = "Absolute change", desc = "Show the price change.", icon = "gear", default = True),
            schema.Toggle(id = "show_percentage_change", name = "Percentage change", desc = "Show the percentage change.", icon = "gear", default = True),
        ],
    )
