#!/bin/sh
set -eu
out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-weather-render-tests.XXXXXX")"
pixlet render apps/localweather/local_weather.star _fixture_scenario=weather --output "$out_dir/weather.webp"
pixlet render apps/localweather/local_weather.star _fixture_scenario=alert --output "$out_dir/alert.webp"
pixlet render apps/localweather/local_weather.star --output "$out_dir/setup-required.webp"
for output in "$out_dir"/*.webp; do test -s "$output"; done
echo "Local Weather deterministic render fixtures passed: $out_dir"
