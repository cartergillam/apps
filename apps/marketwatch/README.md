# Market Watch

Candidate Tronbyt app for server-managed Twelve Data quotes. The server injects
sanitized quote JSON at render time; this Pixlet app never receives a provider
credential. Twelve Data returns real-time **or latest available** prices based
on the active plan and exchange entitlements, so the display does not claim an
unqualified real-time feed.
