# Market Watch

Candidate Tronbyt app for server-managed Twelve Data quotes. The server injects
sanitized quote JSON at render time; this Pixlet app never receives a provider
credential. It accepts one to five unique comma-separated symbols, including
exchange-qualified symbols such as `SHOP:TSX`.

New installations default to `AAPL`, which is suitable for initial Basic-plan
validation. International/exchange-qualified symbols remain supported when the
configured Twelve Data plan includes that exchange.

The display prioritizes ticker, price, movement and quote state. `EOD` appears
only when Twelve Data explicitly marks the quote as end-of-day/delayed; `STALE`
means the server is showing a bounded last-known-good response after an upstream
failure. Twelve Data returns real-time **or latest available** prices according
to the active plan and exchange entitlement, so the app does not claim an
unqualified real-time feed.

Physical error frames are intentionally specific and sanitized: `SETUP
REQUIRED`, `INVALID KEY`, `PLAN REQUIRED`, `BAD SYMBOL`, `RATE LIMITED`, and
`PROVIDER ERROR`. Provider messages and credentials are never passed to Pixlet.

Quotes are cached for about five minutes when any requested market is open and
45 minutes when all are closed. The server retains a successful quote for up to
30 additional minutes as a marked stale fallback, and backs off after a rate
limit response. Market Watch remains candidate-only until physical validation.
