#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/mlb-game-render.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT

off="$output_dir/background-off.webp"
dim="$output_dir/background-dim.webp"
full="$output_dir/background-full.webp"

pixlet render "$repo_root/apps/mlb_game/mlb_game.star" \
  __fixture_render=true team_color_background_style=off \
  --output "$off" --silent
pixlet render "$repo_root/apps/mlb_game/mlb_game.star" \
  __fixture_render=true team_color_background_style=dim \
  --output "$dim" --silent
pixlet render "$repo_root/apps/mlb_game/mlb_game.star" \
  __fixture_render=true team_color_background_style=full \
  --output "$full" --silent

test -s "$off"
test -s "$dim"
test -s "$full"
if cmp -s "$off" "$dim" || cmp -s "$dim" "$full" || cmp -s "$off" "$full"; then
  echo "MLB render regression failed: background styles produced identical frames" >&2
  exit 1
fi

echo "MLB off/dim/full background render variants passed"
