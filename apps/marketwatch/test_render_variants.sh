#!/bin/sh
set -eu
out_dir="${TRONBYT_RENDER_OUTPUT:-$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-market-render-tests.XXXXXX")}"
mkdir -p "$out_dir"
for scenario in aapl open closed tsx delayed eod stale multiple two five same_company logo_absent unchanged long mixed_plan invalid_symbol rate_limited setup invalid_key plan_required provider_error; do
  pixlet render apps/marketwatch/market_watch.star "_fixture_scenario=$scenario" display_mode=focus --max_duration 30000 --output "$out_dir/$scenario.webp"
done
for scenario in aapl two five same_company long mixed_plan; do
  pixlet render apps/marketwatch/market_watch.star "_fixture_scenario=$scenario" display_mode=ticker --max_duration 30000 --output "$out_dir/ticker-$scenario.webp"
done
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=multiple display_mode=two --output "$out_dir/legacy-two.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=aapl display_mode=one --output "$out_dir/legacy-one.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=aapl movement_format=value --output "$out_dir/absolute.webp"
pixlet render apps/marketwatch/market_watch.star '$provider_data=[{"symbol":null,"price":null,"absoluteChange":null,"percentageChange":null,"exchange":null,"currency":null,"logoData":null,"marketStatus":null}]' --output "$out_dir/null-fields.webp"
python3 .github/scripts/assert_webp_dimensions.py "$out_dir"/*.webp
python3 apps/marketwatch/test_animation.py "$out_dir"
echo "Market Watch deterministic render fixtures passed: $out_dir"
