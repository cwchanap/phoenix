#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
report_only=0
update_goldens=0
states=""

for argument in "$@"; do
    case "$argument" in
        --report-only)
            report_only=1
            ;;
        --update-goldens)
            update_goldens=1
            ;;
        --*)
            echo "unknown verify-visual option: $argument" >&2
            exit 2
            ;;
        *)
            states="$states $argument"
            ;;
    esac
done

if [ "$update_goldens" -eq 1 ] && [ "${CI:-}" = "true" ]; then
    echo "refusing --update-goldens in CI" >&2
    exit 2
fi
if [ "$update_goldens" -eq 1 ] && [ "$report_only" -eq 1 ]; then
    echo "--report-only and --update-goldens are mutually exclusive" >&2
    exit 2
fi
if [ -z "$states" ]; then
    states=" 01-hud"
fi

artifact_dir="$root_dir/test_output/ui-visual"
mkdir -p "$artifact_dir"

for state in $states; do
    case "$state" in
        01-hud|02-seed-shop|03-shipping-day14|04-bag|05-almanac|06-calendar|07-dialogue|08-morning-summary|09-sleep|10-pause|11-settings)
            ;;
        *)
        echo "unsupported visual state: $state" >&2
        exit 2
            ;;
    esac
    capture_path="$artifact_dir/$state.png"
    evidence_path="$artifact_dir/$state-2x.png"
    "$godot_bin" --path "$root_dir" --script "$root_dir/tests/visual/capture_ui_states.gd" -- \
        --state="$state" --output="$capture_path" --evidence="$evidence_path"
    echo "candidate_capture=$capture_path"
    echo "candidate_evidence=$evidence_path"
    echo "persistent_capture=$artifact_dir/$state.png"
    echo "persistent_evidence=$artifact_dir/$state-2x.png"

    golden_path="$root_dir/tests/visual/goldens/$state.png"
    if [ "$update_goldens" -eq 1 ]; then
        mkdir -p "$root_dir/tests/visual/goldens"
        cp "$capture_path" "$golden_path"
        echo "updated_golden=$golden_path"
        continue
    fi

    if [ "$report_only" -eq 1 ]; then
        "$godot_bin" --headless --path "$root_dir" --script "$root_dir/tests/visual/compare_ui_states.gd" -- \
            "--state=$state" "--capture=$capture_path" "--golden=$golden_path" --report-only
    else
        "$godot_bin" --headless --path "$root_dir" --script "$root_dir/tests/visual/compare_ui_states.gd" -- \
            "--state=$state" "--capture=$capture_path" "--golden=$golden_path"
    fi
done
