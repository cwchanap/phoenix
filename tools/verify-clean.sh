#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git archive --format=tar HEAD | tar -xf - -C "$tmp"
(
  cd "$tmp"
  mkdir -p addons/gut
  curl -fsSL https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.tar.gz \
    | tar -xz --strip-components=3 -C addons/gut "Gut-9.7.1/addons/gut"
  godot --headless --path . --editor --quit
  godot --headless --path . -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit,res://tests/integration -gexit
  godot --headless --path . --script res://tests/headless/project_smoke.gd
  godot --headless --path . --script res://tests/headless/world_math_smoke.gd
  godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
)
