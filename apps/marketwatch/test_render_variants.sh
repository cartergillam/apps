#!/bin/sh
set -eu
out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-market-render-tests.XXXXXX")"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=quotes display_mode=one --output "$out_dir/one.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=quotes display_mode=two --output "$out_dir/two.webp"
pixlet render apps/marketwatch/market_watch.star _fixture_scenario=stale display_mode=one --output "$out_dir/stale.webp"
pixlet render apps/marketwatch/market_watch.star --output "$out_dir/setup-required.webp"
for output in "$out_dir"/*.webp; do test -s "$output"; done
echo "Market Watch deterministic render fixtures passed: $out_dir"
