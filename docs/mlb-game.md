# MLB Game schedule correctness

`mlb_game.star` resolves the configured team to a stable MLB team ID (`TOR` and `141` both resolve to 141), computes today in the device timezone, and queries a buffered date range around that local day. Every returned game's UTC `gameDate` is converted to the device timezone before comparing dates. UTC midnight therefore cannot move a Toronto display to August 1 while it is still July 31 locally.

Scheduled games are valid before a linescore exists. Selection recognizes scheduled, pregame, warmup, delayed, live, final, postponed, and suspended games; validates home or away numeric team IDs; supports doubleheaders; and excludes non-MLB opponents only when requested. A failed schedule request emits a failure marker and is retried quickly. A successful no-game response is hidden for at most 30 minutes.

Sanitized render diagnostics include the requested range, device-local date/timezone, server UTC time, team ID, returned game count, selected game ID/status, and hide reason. Full upstream payloads are not logged.

Configuration keys:

- `team`: canonical numeric team ID such as `141` (legacy codes such as `TOR` remain accepted).
- `gameday_only`: hide only after a successful schedule response proves no eligible local-date game.
- `include_exhibition_opponents`: permit a non-MLB opponent.
- `team_color_background_style`: `off`, `dim`, or `full`; defaults to `full`.
  Legacy Boolean values remain accepted and map `true` to `full` and `false` to
  `off`.

Run the deterministic regression embedded in the app with:

```sh
pixlet render apps/mlb_game/mlb_game.star __run_regression_tests=true --output /tmp/mlb-regression.webp
```

Render the deterministic visual fixture in all background modes:

```sh
pixlet render apps/mlb_game/mlb_game.star __fixture_render=true team_color_background_style=off --output /tmp/mlb-background-off.webp
pixlet render apps/mlb_game/mlb_game.star __fixture_render=true team_color_background_style=dim --output /tmp/mlb-background-dim.webp
pixlet render apps/mlb_game/mlb_game.star __fixture_render=true team_color_background_style=full --output /tmp/mlb-background-full.webp
```

Run `apps/mlb_game/test_render_variants.sh` to render all three fixtures and
verify that every style changes the resulting frame.

The dropdown is labelled **Team-colour background**. `Dim` renders team hues at
28% channel intensity. The renderer reads both historical Boolean spellings
when the new style key is absent.

It covers Toronto–St. Louis on July 31, 2026, scheduled/pregame/live/delayed/
postponed/suspended/final states, an empty pregame linescore, UTC/local
midnight, the month boundary, home/away, doubleheaders, team code/ID mapping,
empty responses, malformed response shapes, non-JSON upstream failures, and
HTTP failure classification. It also asserts that the no-game retry remains
bounded at 30 minutes.

## Clock freshness

`og_clock.star` emits `TRONBYT-NEXT-RENDER` for the next device-local minute boundary. The server uses that boundary instead of a long generic cache interval, so the displayed minute cannot remain stale merely because the installation render interval is large.
