# NBA Overview

Team-focused companion to NBA Live. Shows team/season, next matchup and
last completed result, skipping unavailable pages. Five seconds per useful page.
Uses server-injected normalized data and cached logos; no Pixlet networking.

Configure Favorite Team and optional Off/Dim/Full team background. iOS uses
the existing searchable friendly-name selector and saves stable numeric IDs.

Regenerate: `python3 tools/sports_overview/generate.py`
Verify all Overview apps: `python3 tools/sports_overview/test_render.py`
See `tools/sports_overview/README.md` for the shared contract and review tooling.
Physical validation remains pending in `docs/BEN_FRAME_VALIDATION.md`.
