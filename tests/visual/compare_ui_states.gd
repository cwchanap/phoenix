extends SceneTree

const CHANNEL_TOLERANCE := 1
const MISMATCH_RATIO_LIMIT := 0.0005
const CONTRACT_CHANNEL_CEILING := 12
const CONTRACT_MISMATCH_RATIO_CEILING := 0.002
const VALIDATION_SCOPE := "macos-local"
const HUD_RECTS := [Rect2i(0, 0, 640, 36), Rect2i(0, 294, 640, 66)]
const FULL_FRAME_RECTS := [Rect2i(0, 0, 640, 360)]

func _initialize() -> void:
    var state_name := "01-hud"
    var capture_path := ""
    var golden_path := ""
    var report_only := false
    for argument in OS.get_cmdline_user_args():
        if argument == "--report-only":
            report_only = true
        elif argument.begins_with("--state="):
            state_name = argument.trim_prefix("--state=")
        elif argument.begins_with("--capture="):
            capture_path = argument.trim_prefix("--capture=")
        elif argument.begins_with("--golden="):
            golden_path = argument.trim_prefix("--golden=")

    if not [
        "01-hud",
        "02-seed-shop",
        "03-shipping-day14",
        "04-bag",
        "05-almanac",
        "06-calendar",
        "07-dialogue",
        "08-morning-summary",
        "09-sleep",
        "10-pause",
        "11-settings",
    ].has(state_name):
        push_error("unsupported visual state: %s" % state_name)
        quit(2)
        return
    if capture_path == "" or not FileAccess.file_exists(ProjectSettings.globalize_path(capture_path)):
        push_error("capture is missing: %s" % capture_path)
        quit(2)
        return

    var capture := load_raw(capture_path)
    if capture == null or capture.is_empty() or capture.get_width() != 640 or capture.get_height() != 360:
        push_error("capture must be a non-empty 640x360 image: %s" % capture_path)
        quit(2)
        return
    print("state=%s" % state_name)
    print("capture=%s" % capture_path)
    if golden_path == "" or not FileAccess.file_exists(ProjectSettings.globalize_path(golden_path)):
        print("golden_missing=true")
        print("validation_scope=%s" % VALIDATION_SCOPE)
        print("max_channel_delta=unavailable")
        print("differing_pixels=unavailable")
        print("pixels_over_tolerance=unavailable")
        print("pixels_over_contract_channel_ceiling=unavailable")
        print("compared_pixels=unavailable")
        print("mismatch_ratio=unavailable")
        quit(0 if report_only else 2)
        return

    var golden := load_raw(golden_path)
    if golden == null or golden.is_empty() or golden.get_width() != 640 or golden.get_height() != 360:
        push_error("golden must be a non-empty 640x360 image: %s" % golden_path)
        quit(2)
        return
    var metrics := compare_images(capture, golden, state_name)
    print("golden_missing=false")
    print("validation_scope=%s" % VALIDATION_SCOPE)
    print("max_channel_delta=%d" % int(metrics["max_channel_delta"]))
    print("differing_pixels=%d" % int(metrics["differing_pixels"]))
    print("pixels_over_tolerance=%d" % int(metrics["pixels_over_tolerance"]))
    print("pixels_over_contract_channel_ceiling=%d" % int(metrics["pixels_over_contract_channel_ceiling"]))
    print("compared_pixels=%d" % int(metrics["compared_pixels"]))
    print("mismatch_ratio=%.8f" % float(metrics["mismatch_ratio"]))
    if report_only:
        quit(0)
        return
    if CHANNEL_TOLERANCE > CONTRACT_CHANNEL_CEILING or MISMATCH_RATIO_LIMIT > CONTRACT_MISMATCH_RATIO_CEILING:
        push_error("macOS-local visual thresholds exceed the contract ceilings")
        quit(2)
        return

    if int(metrics["max_channel_delta"]) > CHANNEL_TOLERANCE or float(metrics["mismatch_ratio"]) > MISMATCH_RATIO_LIMIT:
        push_error("visual state %s exceeds macOS-local thresholds" % state_name)
        quit(2)
        return
    quit(0)

func compare_images(capture: Image, golden: Image, state_name: String = "01-hud") -> Dictionary:
    var max_channel_delta := 0
    var differing_pixels := 0
    var pixels_over_tolerance := 0
    var pixels_over_contract_channel_ceiling := 0
    var compared_pixels := 0
    var rects := FULL_FRAME_RECTS if state_name != "01-hud" else HUD_RECTS
    for rect in rects:
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                var delta := _pixel_delta(capture.get_pixel(x, y), golden.get_pixel(x, y))
                max_channel_delta = maxi(max_channel_delta, int(delta))
                if delta > 0.0:
                    differing_pixels += 1
                if delta > float(CHANNEL_TOLERANCE):
                    pixels_over_tolerance += 1
                if delta > float(CONTRACT_CHANNEL_CEILING):
                    pixels_over_contract_channel_ceiling += 1
                compared_pixels += 1
    return {
        "max_channel_delta": max_channel_delta,
        "differing_pixels": differing_pixels,
        "pixels_over_tolerance": pixels_over_tolerance,
        "pixels_over_contract_channel_ceiling": pixels_over_contract_channel_ceiling,
        "compared_pixels": compared_pixels,
        "mismatch_ratio": float(pixels_over_tolerance) / float(maxi(compared_pixels, 1)),
    }

func _pixel_delta(left: Color, right: Color) -> float:
    var left_r := roundi(left.r * 255.0)
    var left_g := roundi(left.g * 255.0)
    var left_b := roundi(left.b * 255.0)
    var left_a := roundi(left.a * 255.0)
    var right_r := roundi(right.r * 255.0)
    var right_g := roundi(right.g * 255.0)
    var right_b := roundi(right.b * 255.0)
    var right_a := roundi(right.a * 255.0)
    return maxf(
        maxf(float(absi(left_r - right_r)), float(absi(left_g - right_g))),
        maxf(float(absi(left_b - right_b)), float(absi(left_a - right_a))),
    )

static func load_raw(path: String) -> Image:
    return Image.load_from_file(ProjectSettings.globalize_path(path))
