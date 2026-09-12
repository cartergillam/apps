#!/bin/sh
set -eu
out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-market-render-tests.XXXXXX")"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=open display_mode=one --output "$out_dir/open.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=closed display_mode=one --output "$out_dir/closed.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=tsx display_mode=one --output "$out_dir/tsx.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=delayed display_mode=one --output "$out_dir/delayed.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=stale display_mode=one --output "$out_dir/stale.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=multiple display_mode=one --output "$out_dir/multiple.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=multiple display_mode=two --output "$out_dir/two.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=invalid_symbol --output "$out_dir/invalid-symbol.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=rate_limited --output "$out_dir/rate-limited.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=setup --output "$out_dir/setup-required.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=invalid_key --output "$out_dir/invalid-key.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=plan_required --output "$out_dir/plan-required.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=provider_error --output "$out_dir/provider-error.webp"
for output in "$out_dir"/*.webp; do test -s "$output"; done
python3 .github/scripts/assert_webp_dimensions.py "$out_dir"/*.webp
echo "Market Watch deterministic render fixtures passed: $out_dir"
