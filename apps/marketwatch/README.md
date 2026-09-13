# Market Watch

Candidate Tronbyt app for server-managed Twelve Data quotes. The server injects
sanitized quote JSON at render time; this Pixlet app never receives a provider
credential. It accepts one to ten unique comma-separated symbols, including
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
independent of mode, stock order, device or installation. OPEN target freshness is
five minutes (six for watchlists above eight listings); CLOSED/unknown freshness is 60 minutes. Confirmed closing quotes
for known North American venues can persist until the next weekday opening.
Last-known-good quotes remain available for 72 additional hours as STALE.
Search caches for 24 hours. Remote logos cache for 30 days; Apple and Microsoft
use approved bundled transparent overrides on the server, with no provider logo
calls. Provider errors and quota deferrals do not restart refreshes per render.

Ten symbols at a conservative six-minute cadence over a 6.5-hour session use approximately
650 quote credits, plus a few initial/closing snapshots. Batches save HTTP calls,
not per-symbol credits. The server reserves Basic-plan minute credits, observes
normal response credit headers, and retains local daily headroom for search,
validation and retries. See server `internal/providers/MARKET_WATCH_QUOTA.md` for
budget limits, market/session caveats and process-cache lifetime.

Ticker timing remains 55 ms per one-pixel step. Focus keeps its fixed 64×32
composition. Ticker uses actual measured text widths: fixed 20px logo canvas,
2px logo/text spacing, four aligned text rows (symbol/price/movement/currency),
and a five-pixel allocated inter-item gap. Transparent logo/text edges yield
physical visible gaps no larger than ten pixels in the fixtures. Short symbols
are not padded to long-symbol width. Pathological symbols truncate to ten compact
characters with `~`; PLAN REQUIRED displays compact PLAN in the same item.
STALE/EOD/DELAY occupy the fixed space beneath the logo without changing item width.
Venue/MIC labels remain absent. Approved logos and fallback initials retain their
fixed canvas. The denser tape remains readable at 55ms; no timing change is needed.

Bounded strips advance by each measured item width, with repeated following items
to supply 64px of reference pixels, including a one-item loop narrower than the
viewport. Every boundary, including last-to-first, uses the same gap. The ten-stock
fixture now contains 540 frames / 29.7 seconds (formerly 960 / 52.8 seconds).
Server quote/cache/quota logic and Focus layout are unchanged by density work.
CLOSED text is omitted in both modes; a valid closing quote renders normally.
Device credential assignments are automatic; owner-authorized legacy overrides
remain supported.
`test_render_variants.sh` validates 64×32 fixtures, 1/2/5/10-symbol animation timing,
every adjacent/wraparound step, and identical OPEN/CLOSED/STALE quote geometry.
`test_layout.py` compares metadata-only variants pixel-for-pixel, tests currency
and error slot isolation, fixed logo/text anchors, mixed-strip card boundaries,
synthetic wide/tall remote artwork and large-price clipping. Animation tests
reconstruct every strip, check measured widths and visible gaps <=10px, and verify
each adjacent pixel step and loop boundary. All tests are offline.
