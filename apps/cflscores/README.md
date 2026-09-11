# CFL Scores for Tidbyt

Displays server-normalized CFL games on a 64×32 display. Favorite Team mode
shows the selected club's current game or upcoming opponent and device-local
kickoff time. League mode rotates active games and includes halftime and
overtime.

The app no longer contacts ESPN or third-party image hosts. Tronbyt Server owns
provider access, stable numeric team selection, state normalization, cache
coalescing, and bounded stale fallback. Team abbreviations and colors provide a
deterministic fallback instead of remote logos.

Compatibility behavior:

- `scoreMode=auto` plus a numeric `selectedTeam` follows that favorite.
- `scoreMode=auto` plus `selectedTeam=all` uses the league live view.
- Existing `favorite` and `league` values remain valid.
- Legacy visual modes map safely to the team-color renderer unless they are
  `black` or `retro`.
- The retired odds option falls back to team records; stored location data is
  ignored because kickoff presentation now always uses the device timezone.
