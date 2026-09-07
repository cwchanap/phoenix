#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
report_only=0
update_goldens=0
states=""
all_states="01-hud 02-seed-shop 03-shipping-day14 04-bag 05-almanac 06-calendar 07-dialogue 08-morning-summary 09-sleep 10-pause 11-settings 12-intro 13-title 14-result-heart-of-harvest"

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
    states="$all_states"
fi

artifact_dir="$root_dir/test_output/ui-visual"
mkdir -p "$artifact_dir"
capture_timeout_seconds=${PHOENIX_VISUAL_CAPTURE_TIMEOUT_SECONDS:-60}
case "$capture_timeout_seconds" in
    ''|*[!0-9]*)
        echo "PHOENIX_VISUAL_CAPTURE_TIMEOUT_SECONDS must be a non-negative integer" >&2
        exit 2
        ;;
esac

wait_for_capture() {
    capture_pid=$1
    elapsed_seconds=0
    while kill -0 "$capture_pid" 2>/dev/null; do
        if [ "$elapsed_seconds" -ge "$capture_timeout_seconds" ]; then
            echo "visual capture timed out after ${capture_timeout_seconds}s; terminating pid $capture_pid" >&2
            kill -TERM "$capture_pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$capture_pid" 2>/dev/null; then
                kill -KILL "$capture_pid" 2>/dev/null || true
            fi
            wait "$capture_pid" 2>/dev/null || true
            return 124
        fi
        sleep 1
        elapsed_seconds=$((elapsed_seconds + 1))
    done
    wait "$capture_pid"
}

for state in $states; do
    case "$state" in
        01-hud|02-seed-shop|03-shipping-day14|04-bag|05-almanac|06-calendar|07-dialogue|08-morning-summary|09-sleep|10-pause|11-settings|12-intro|13-title|14-result-heart-of-harvest)
            ;;
        *)
        echo "unsupported visual state: $state" >&2
        exit 2
            ;;
    esac
    capture_path="$artifact_dir/$state.png"
    evidence_path="$artifact_dir/$state-2x.png"
    diff_path="$artifact_dir/diff/$state.png"
    rm -f "$capture_path" "$evidence_path" "$diff_path"
    "$godot_bin" --path "$root_dir" --quit-after 120 --script "$root_dir/tests/visual/capture_ui_states.gd" -- \
        --state="$state" --output="$capture_path" --evidence="$evidence_path" &
    capture_pid=$!
    capture_status=0
    if wait_for_capture "$capture_pid"; then
        :
    else
        capture_status=$?
    fi
    if [ "$capture_status" -ne 0 ]; then
        echo "visual capture command failed for $state (exit $capture_status)" >&2
        exit "$capture_status"
    fi
    if [ ! -s "$capture_path" ] || [ ! -s "$evidence_path" ]; then
        echo "capture did not produce fresh output for $state" >&2
        exit 1
    fi
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
            "--state=$state" "--capture=$capture_path" "--golden=$golden_path" "--diff=$diff_path" --report-only
    else
        "$godot_bin" --headless --path "$root_dir" --script "$root_dir/tests/visual/compare_ui_states.gd" -- \
            "--state=$state" "--capture=$capture_path" "--golden=$golden_path" "--diff=$diff_path"
    fi
done
