#!/bin/sh
set -eu
out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-nhl-render-tests.XXXXXX")"
for scenario in scheduled pregame live_p1 live_p2 live_p3 intermission overtime shootout final final_ot final_so delayed postponed suspended cancelled stale timezone_boundary future no_games worst_case; do
  pixlet render apps/nhllive/nhl_live.star "_fixture_scenario=$scenario" '$tz=America/Toronto' --output "$out_dir/$scenario.webp"
done
pixlet render apps/nhllive/nhl_live.star _fixture_scenario=multiple mode=all_live --output "$out_dir/multiple.webp"
pixlet render apps/nhllive/nhl_live.star _fixture_scenario=no_live mode=all_live --output "$out_dir/no-live.webp"
pixlet render apps/nhllive/nhl_live.star _fixture_scenario=live_p1 team_color_background_style=off --output "$out_dir/background-off.webp"
pixlet render apps/nhllive/nhl_live.star _fixture_scenario=live_p1 team_color_background_style=full --output "$out_dir/background-full.webp"
pixlet render apps/nhllive/nhl_live.star '$provider_error={"code":"sports_provider_unavailable","message":"NHL data is temporarily unavailable"}' --output "$out_dir/provider-error.webp"
for output in "$out_dir"/*.webp; do test -s "$output"; done
python3 .github/scripts/assert_webp_dimensions.py "$out_dir"/*.webp
echo "NHL Live deterministic render fixtures passed: $out_dir"
