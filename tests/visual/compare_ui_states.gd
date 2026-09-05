extends SceneTree

const CHANNEL_TOLERANCE := 12
const MISMATCH_RATIO_LIMIT := 0.002
const CALIBRATION_STATUS := "unconfigured"
const HUD_RECTS := [Rect2i(0, 0, 640, 36), Rect2i(0, 294, 640, 66)]

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

    if state_name != "01-hud":
        push_error("unsupported visual state: %s" % state_name)
        quit(2)
        return
    if capture_path == "" or not FileAccess.file_exists(ProjectSettings.globalize_path(capture_path)):
        push_error("capture is missing: %s" % capture_path)
        quit(2)
        return

    var capture := load_raw(capture_path)
    if capture.is_empty() or capture.get_width() != 640 or capture.get_height() != 360:
        push_error("capture must be a non-empty 640x360 image: %s" % capture_path)
        quit(2)
        return
    print("state=%s" % state_name)
    print("capture=%s" % capture_path)
    if golden_path == "" or not FileAccess.file_exists(ProjectSettings.globalize_path(golden_path)):
        print("golden_missing=true")
        print("max_channel_delta=unavailable")
        print("differing_pixels=unavailable")
        print("compared_pixels=unavailable")
        print("mismatch_ratio=unavailable")
        quit(0 if report_only else 2)
        return

    var golden := load_raw(golden_path)
    if golden.is_empty() or golden.get_width() != 640 or golden.get_height() != 360:
        push_error("golden must be a non-empty 640x360 image: %s" % golden_path)
        quit(2)
        return
    var metrics := compare_images(capture, golden)
    print("golden_missing=false")
    print("calibration_status=%s" % CALIBRATION_STATUS)
    print("max_channel_delta=%d" % int(metrics["max_channel_delta"]))
    print("differing_pixels=%d" % int(metrics["differing_pixels"]))
    print("pixels_over_contract_channel_ceiling=%d" % int(metrics["differing_pixels"]))
    print("compared_pixels=%d" % int(metrics["compared_pixels"]))
    print("mismatch_ratio=%.8f" % float(metrics["mismatch_ratio"]))
    if report_only:
        quit(0)
        return
    if CALIBRATION_STATUS != "calibrated":
        push_error("visual thresholds are unconfigured; run report-only and calibrate macOS/Linux drift before normal comparison")
        quit(2)
        return

    if int(metrics["max_channel_delta"]) > CHANNEL_TOLERANCE or float(metrics["mismatch_ratio"]) > MISMATCH_RATIO_LIMIT:
        push_error("visual state %s exceeds calibrated thresholds" % state_name)
        quit(2)
        return
    quit(0)

func compare_images(capture: Image, golden: Image) -> Dictionary:
    var max_channel_delta := 0
    var differing_pixels := 0
    var compared_pixels := 0
    for rect in HUD_RECTS:
        for y in range(rect.position.y, rect.end.y):
            for x in range(rect.position.x, rect.end.x):
                var delta := _pixel_delta(capture.get_pixel(x, y), golden.get_pixel(x, y))
                max_channel_delta = maxi(max_channel_delta, int(ceil(delta)))
                if delta > CHANNEL_TOLERANCE:
                    differing_pixels += 1
                compared_pixels += 1
    return {
        "max_channel_delta": max_channel_delta,
        "differing_pixels": differing_pixels,
        "compared_pixels": compared_pixels,
        "mismatch_ratio": float(differing_pixels) / float(maxi(compared_pixels, 1)),
    }

func _pixel_delta(left: Color, right: Color) -> float:
    return maxf(
        maxf(absf(left.r - right.r), absf(left.g - right.g)),
        maxf(absf(left.b - right.b), absf(left.a - right.a)),
    ) * 255.0

static func load_raw(path: String) -> Image:
    return Image.load_from_file(ProjectSettings.globalize_path(path))
