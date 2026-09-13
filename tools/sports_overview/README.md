# Overview display tooling

`generate.py` reproduces NHL/NBA/NFL standalone Overview apps from the common
Starlark template and existing read-only Live team catalogs. This avoids three
independently drifting layouts without requiring external Pixlet module loading.

`python3 tools/sports_overview/test_render.py` renders deterministic offline
fixtures and checks all frames are 64×32 and useful page counts/5-second duration
are correct. Covers normal/extreme records, home/away, postponement, OT/SO/tie,
three-digit scores, nulls, missing times/logos, wide/tall logos and background
styles. It exports actual Pixlet schemas and creates labelled nearest-neighbor
review montages at `/tmp/nhl-overview-review.png`, `/tmp/nba-overview-review.png`
and `/tmp/nfl-overview-review.png`. No test contacts a provider. Logo fixtures use
existing local Live assets; NHL's old flat fixture is replaced by the existing
transparent Leafs source PNG for a meaningful review.

Render contract: `$overview_data`, with team, season, standing, nextGame, lastGame
and stale. Teams and games reuse server sports fields. Nullable values are
normalized at every boundary; invalid scores show --; missing useful pages are
skipped. Server-generated local labels avoid any Pixlet timestamp parsing.

The label helper measures text before rendering and uses compact bounded text for
pathological inputs. Logos always have fixed canvases. Normal current team names
are selected through friendly static schemas; stored values remain numeric IDs.

See server `internal/providers/SPORTS_OVERVIEW.md` for endpoint/cache semantics,
rank limitations and provider-neutral contracts. See
`docs/BEN_FRAME_VALIDATION.md` for all pending physical checks, including Weather
and Market Watch. Overview remains a candidate until physical approval.
