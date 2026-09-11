# NBA Live

NBA Live is a candidate Tronbyt app backed by server-normalized ESPN Site scoreboard data. Pixlet receives only the shared sports contract and never calls ESPN directly.

It supports a stable ESPN numeric team selection or a league-wide view of all active games. Scheduled times use the device timezone, live and halftime games refresh through the shared provider cache, and bounded fallback data is visibly marked `STALE`.

The existing `nba-scores` and `nba-standings` community apps remain separate and unchanged. NBA Live intentionally uses abbreviation/color fallbacks rather than third-party logo hosting.
