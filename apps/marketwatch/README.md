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

The server shares individual listing snapshots within credential owner scope,
independent of mode, stock order, device or installation. OPEN freshness is
three minutes; CLOSED/unknown freshness is 60 minutes. Confirmed closing quotes
for known North American venues can persist until the next weekday opening.
Last-known-good quotes remain available for 72 additional hours as STALE.
Search caches for 24 hours. Remote logos cache for 30 days; Apple and Microsoft
use approved bundled transparent overrides on the server, with no provider logo
calls. Provider errors and quota deferrals do not restart refreshes per render.

Five symbols at three-minute freshness over a 6.5-hour session use approximately
650 quote credits, plus a few initial/closing snapshots. Batches save HTTP calls,
not per-symbol credits. The server reserves Basic-plan minute credits, observes
normal response credit headers, and retains local daily headroom for search,
validation and retries. See server `internal/providers/MARKET_WATCH_QUOTA.md` for
budget limits, market/session caveats and process-cache lifetime.

Ticker timing is 55 ms per one-pixel step (formerly 40 ms). Every ticker card
has fixed 32-pixel geometry and a permanent seven-pixel status region. Logos
render without a background fill; acquisition failures use ticker letters.
`test_render_variants.sh` validates 64×32 fixtures, 1/2/5-symbol animation timing,
every adjacent/wraparound step, and identical OPEN/CLOSED/STALE quote geometry.
