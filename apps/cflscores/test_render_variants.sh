#!/bin/sh
set -eu

out_dir="$(mktemp -d "${TMPDIR:-/tmp}/tronbyt-cfl-render-tests.XXXXXX")"

for scenario in live final today tomorrow future postponed cancelled empty; do
  pixlet render apps/cflscores/cfl_scores.star \
    selectedTeam=85 scoreMode=auto displayType=stadium \
    _fixture_now=2026-08-06T16:00Z _fixture_scenario="$scenario" \
    --output "$out_dir/$scenario.webp"
done

for output in "$out_dir"/*.webp; do test -s "$output"; done

echo "CFL deterministic render fixtures passed: $out_dir"
