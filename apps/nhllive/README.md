# NHL Live Applet for Tidbyt

Displays server-normalized NHL scores and status on a 64×32 display. Favorite
Team mode shows the selected club's current game or its next local puck-drop;
All Live Games mode rotates every active game in deterministic order.

The app intentionally uses team abbreviations and colors instead of remote
logos. NHL API access, state normalization, caching, stale fallback, and stable
numeric team selection are handled by Tronbyt Server. Existing `teamid=0`
installations map safely to All Live Games; existing non-zero numeric team IDs
continue to select that favorite team. Older presentation/stat settings are
ignored.

![NHL Live Applet for Tidbyt](screenshot.png)
