# NFL Live

NFL Live is a candidate Tronbyt app backed by server-normalized ESPN Site scoreboard data. Pixlet receives only the shared sports contract and never calls ESPN directly.

It supports a stable ESPN numeric team selection or a league-wide view of all active games. Scheduled kickoffs use the device timezone, active games use the shared coalesced provider cache, and bounded fallback data is visibly marked `STALE`.

The existing `nfl-scores`, `nfl-standings`, and `nfl-division-standings` community apps remain separate and unchanged. NFL Live intentionally uses abbreviation/color fallbacks rather than external logos.
