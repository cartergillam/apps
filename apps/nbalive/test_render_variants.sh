#!/bin/sh
set -eu

out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-nba-render-tests.XXXXXX")"

for scenario in off_day future scheduled pregame q1 q2 halftime q3 q4 ot double_ot final final_ot delayed postponed cancelled suspended unknown stale timezone_boundary empty; do
  pixlet render apps/nbalive/nba_live.star \
    mode=favorite teamid=28 team_color_background_style=dim '$tz=America/Toronto' \
    _fixture_now=2026-10-01T16:00:00Z "_fixture_scenario=$scenario" \
    --output "$out_dir/$scenario.webp"
done

pixlet render apps/nbalive/nba_live.star mode=all_live _fixture_scenario=multiple --output "$out_dir/multiple.webp"
pixlet render apps/nbalive/nba_live.star mode=all_live _fixture_scenario=no_live '$tz=America/Toronto' --output "$out_dir/no-live.webp"
pixlet render apps/nbalive/nba_live.star _fixture_scenario=q3 team_color_background_style=off --output "$out_dir/background-off.webp"
pixlet render apps/nbalive/nba_live.star _fixture_scenario=q3 team_color_background_style=full --output "$out_dir/background-full.webp"
pixlet render apps/nbalive/nba_live.star '$provider_error={"code":"sports_provider_unavailable","message":"Sports data is temporarily unavailable"}' --output "$out_dir/provider-error.webp"
pixlet render apps/nbalive/nba_live.star '$provider_error={"code":"sports_team_invalid","message":"NBA team selection is not available"}' --output "$out_dir/invalid-team.webp"
pixlet render apps/nbalive/nba_live.star '$sports_data={"league":"nba","provider":"espn-site","deviceTimezone":"America/Toronto","games":[],"freshAsOf":"2026-10-01T16:00:00Z","stale":false}' mode=all_live --output "$out_dir/server-contract.webp"

for output in "$out_dir"/*.webp; do test -s "$output"; done

echo "NBA Live deterministic render fixtures passed: $out_dir"
