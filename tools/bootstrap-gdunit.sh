#!/usr/bin/env bash
# Installs the pinned GdUnit4 + godot-e2e addons into addons/ (gitignored).
# Mirrors verify-clean.sh conventions: pinned archives, sha256 verified.
set -euo pipefail

GDUNIT4_VERSION="6.2.1"
GDUNIT4_SHA256="ffb48847c46f386bf0c7a716fd68c6dace7d67730775cf7f748adce8ef3ed794"
E2E_COMMIT="53fa06cebe5c59d3b8794146f040c0a9a0aef9cb"
E2E_SHA256="77f579de3a01d5ccf6e526607869f9734f80edbf94f0373535eb649c9b06f1a7"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$(command -v godot || true)}"

if [ -d "$root/addons/gdUnit4" ] && [ -d "$root/addons/gdunit_e2e" ]; then
  echo "addons/gdUnit4 and addons/gdunit_e2e already present"
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL "https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v${GDUNIT4_VERSION}.zip" -o "$tmp/gdunit4.zip"
  echo "$GDUNIT4_SHA256  $tmp/gdunit4.zip" | shasum -a 256 -c -
  unzip -q "$tmp/gdunit4.zip" -d "$tmp/gdunit4"

  curl -fsSL "https://github.com/cwchanap/godot-e2e/archive/${E2E_COMMIT}.zip" -o "$tmp/e2e.zip"
  echo "$E2E_SHA256  $tmp/e2e.zip" | shasum -a 256 -c -
  unzip -q "$tmp/e2e.zip" -d "$tmp/e2e"

  mkdir -p "$root/addons"
  cp -R "$tmp"/gdunit4/*/addons/gdUnit4 "$root/addons/gdUnit4"
  cp -R "$tmp"/e2e/*/addons/gdunit_e2e "$root/addons/gdunit_e2e"
fi

if [ -n "$godot_bin" ] && [ -x "$godot_bin" ]; then
  "$godot_bin" --headless --editor --path "$root" --quit
else
  echo "godot not found; skipping editor import pass" >&2
fi
