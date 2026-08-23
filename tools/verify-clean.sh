#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git archive --format=tar HEAD | tar -xf - -C "$tmp"
(
  cd "$tmp"
  godot --headless --path . --editor --quit
  godot --headless --path . -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit,res://tests/integration -gexit
  godot --headless --path . --script res://tests/headless/project_smoke.gd
  godot --headless --path . --script res://tests/headless/world_math_smoke.gd
  godot --headless --path . --script res://tests/headless/world_shell_smoke.gd
)
