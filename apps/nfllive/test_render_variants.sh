#!/bin/sh
set -eu

out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-nfl-render-tests.XXXXXX")"

for scenario in off_day future scheduled pregame q1 q2 halftime q3 q4 zero_clock quarter_break ot final final_ot tie delayed postponed cancelled suspended unknown stale timezone_boundary empty worst_case; do
  pixlet render apps/nfllive/nfl_live.star \
    mode=favorite teamid=2 team_color_background_style=dim '$tz=America/Toronto' \
    _fixture_now=2026-09-10T16:00:00Z "_fixture_scenario=$scenario" \
    --output "$out_dir/$scenario.webp"
done

pixlet render apps/nfllive/nfl_live.star mode=all_live _fixture_scenario=multiple --output "$out_dir/multiple.webp"
pixlet render apps/nfllive/nfl_live.star mode=all_live _fixture_scenario=no_live '$tz=America/Toronto' --output "$out_dir/no-live.webp"
pixlet render apps/nfllive/nfl_live.star _fixture_scenario=q3 team_color_background_style=off --output "$out_dir/background-off.webp"
pixlet render apps/nfllive/nfl_live.star _fixture_scenario=q3 team_color_background_style=full --output "$out_dir/background-full.webp"
pixlet render apps/nfllive/nfl_live.star '$provider_error={"code":"sports_provider_unavailable","message":"Sports data is temporarily unavailable"}' --output "$out_dir/provider-error.webp"
pixlet render apps/nfllive/nfl_live.star '$provider_error={"code":"sports_team_invalid","message":"NFL team selection is not available"}' --output "$out_dir/invalid-team.webp"
pixlet render apps/nfllive/nfl_live.star '$sports_data={"league":"nfl","provider":"espn-site","deviceTimezone":"America/Toronto","games":[],"freshAsOf":"2026-09-10T16:00:00Z","stale":false}' mode=all_live --output "$out_dir/server-contract.webp"
pixlet render apps/nfllive/nfl_live.star '$sports_data={"league":"nfl","games":null,"upcomingGames":null,"nextGame":null,"stale":null}' --output "$out_dir/null-collections.webp"
pixlet render apps/nfllive/nfl_live.star '$sports_data={"league":"nfl","games":[{"awayTeam":null,"homeTeam":{"abbreviation":null,"primaryColor":null,"logoData":null},"status":null,"awayScore":null,"homeScore":null,"awayRecord":null,"homeRecord":null,"scheduledAt":null,"scheduledLocal":null,"statusDetail":null,"stale":null}],"upcomingGames":null,"nextGame":null,"stale":null}' --output "$out_dir/null-game-fields.webp"

for output in "$out_dir"/*.webp; do test -s "$output"; done
python3 .github/scripts/assert_webp_dimensions.py "$out_dir"/*.webp
echo "NFL Live deterministic render fixtures passed: $out_dir"
