#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/mlb-game-render.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT

enabled="$output_dir/background-enabled.webp"
disabled="$output_dir/background-disabled.webp"

pixlet render "$repo_root/apps/mlb_game/mlb_game.star" \
  __fixture_render=true show_team_colored_logo_background=true \
  --output "$enabled" --silent
pixlet render "$repo_root/apps/mlb_game/mlb_game.star" \
  __fixture_render=true show_team_colored_logo_background=false \
  --output "$disabled" --silent

test -s "$enabled"
test -s "$disabled"
if cmp -s "$enabled" "$disabled"; then
  echo "MLB render regression failed: background toggle produced identical frames" >&2
  exit 1
fi

echo "MLB background render variants passed"
