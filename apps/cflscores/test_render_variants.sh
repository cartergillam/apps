#!/bin/sh
set -eu

out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-cfl-render-tests.XXXXXX")"

for scenario in scheduled pregame q1 q2 q3 q4 halftime overtime final final_ot delayed postponed cancelled suspended stale timezone_boundary future off_day empty worst_case; do
  pixlet render apps/cflscores/cfl_scores.star \
    selectedTeam=85 scoreMode=auto displayType=colors '$tz=America/Toronto' \
    _fixture_now=2026-08-06T16:00:00Z _fixture_scenario="$scenario" \
    --output "$out_dir/$scenario.webp"
done

pixlet render apps/cflscores/cfl_scores.star selectedTeam=all scoreMode=league _fixture_scenario=multiple --output "$out_dir/multiple.webp"
pixlet render apps/cflscores/cfl_scores.star selectedTeam=all scoreMode=auto _fixture_scenario=no_live '$tz=America/Toronto' --output "$out_dir/no-live.webp"
pixlet render apps/cflscores/cfl_scores.star selectedTeam=85 scoreMode=auto _fixture_scenario=q3 displayType=black --output "$out_dir/black.webp"
pixlet render apps/cflscores/cfl_scores.star selectedTeam=85 scoreMode=favorite _fixture_scenario=scheduled displayType=logos pregameDisplay=odds 'location={"timezone":"America/Vancouver"}' '$tz=America/Toronto' --output "$out_dir/legacy-config.webp"
pixlet render apps/cflscores/cfl_scores.star '$provider_error={"code":"sports_provider_unavailable","message":"Sports data is temporarily unavailable"}' --output "$out_dir/provider-error.webp"
pixlet render apps/cflscores/cfl_scores.star '$sports_data={"league":"cfl","provider":"espn-site","deviceTimezone":"America/Toronto","games":[],"freshAsOf":"2026-08-06T16:00:00Z","stale":false}' selectedTeam=all --output "$out_dir/server-contract.webp"
pixlet render apps/cflscores/cfl_scores.star '$sports_data={"league":"cfl","games":null,"upcomingGames":null,"nextGame":null,"stale":null}' --output "$out_dir/null-collections.webp"
pixlet render apps/cflscores/cfl_scores.star '$sports_data={"league":"cfl","games":[{"awayTeam":null,"homeTeam":{"abbreviation":null,"primaryColor":null,"logoData":null},"status":null,"awayScore":null,"homeScore":null,"awayRecord":null,"homeRecord":null,"scheduledAt":null,"statusDetail":null,"stale":null}],"upcomingGames":null,"nextGame":null,"stale":null}' --output "$out_dir/null-game-fields.webp"

for output in "$out_dir"/*.webp; do test -s "$output"; done
python3 .github/scripts/assert_webp_dimensions.py "$out_dir"/*.webp
echo "CFL deterministic render fixtures passed: $out_dir"
