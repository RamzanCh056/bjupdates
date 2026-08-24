# pro_video_editor 0.3.0 – API summary

Your project uses **pro_video_editor: ^0.3.0**. Here’s what the package supports in this version (from the pub cache).

---

## RenderVideoModel (export) – supported fields

| Parameter          | Type                  | Description |
|--------------------|-----------------------|-------------|
| `video`            | `EditorVideo`         | **Required.** Source video (`.file()`, `.asset()`, `.network()`, `.memory()`). |
| `outputFormat`     | `VideoOutputFormat`   | **Required.** `mp4` or `mov` (mov only on iOS/macOS). |
| `imageBytes`       | `Uint8List?`         | **Single overlay image** (e.g. PNG) composited on top of the video for the whole duration. |
| `transform`        | `ExportTransform?`    | Crop, scale, rotate, flip, offset. |
| `enableAudio`      | `bool` (default true) | Include **original video audio** in the export. |
| `playbackSpeed`    | `double?`            | e.g. 0.5, 1.0, 2.0. |
| `startTime`        | `Duration?`          | Trim start. |
| `endTime`          | `Duration?`          | Trim end (must be &gt; startTime). |
| `colorMatrixList`  | `List<List<double>>` | **Color filters.** Each inner list = one 4×5 matrix (20 values, row-major). |
| `blur`             | `double?`            | Blur strength. |
| `bitrate`          | `int?`               | Output bitrate (bits/sec). |
| `qualityConfig`    | `VideoQualityConfig?`| Alternative to manual bitrate/transform. |
| `id`               | `String?`            | Task id for progress stream. |

---

## What 0.3.0 does **not** support

- **Custom / background audio**  
  There is no parameter for a second audio track (e.g. music from browser). Only the original video’s audio can be kept or muted via `enableAudio`. Newer versions of the package on pub.dev may add something like `customAudioPath`; 0.3.0 does not have it.

- **Multiple or time-based overlays**  
  Only one `imageBytes` overlay, applied for the full duration. No API for multiple layers or time ranges.

- **Baked-in text / emoji from the editor**  
  Text and stickers in your editor are only in the Flutter UI. To get them into the exported file you must:
  - Render them into a **single image** (e.g. same size as video, transparent background),
  - Pass that image as `imageBytes`.
  The plugin does not accept text or emoji directly.

---

## What you can do with 0.3.0

1. **Apply the selected filter in export**  
   Your editor already has filter names (Vintage, Warm, Cool, etc.). Convert each to a 4×5 color matrix (20 `double`s, same as Flutter’s `ColorFilter.matrix`) and pass a list of one (or more) such matrices in `colorMatrixList`. Then the exported video will have that filter applied.

2. **Single image overlay (text + stickers)**  
   When exporting, render the current text + sticker layout into one image (e.g. 720×1280 PNG with transparency), then pass it as `imageBytes`. That overlay will appear for the whole trimmed clip.

3. **Background music**  
   - **In editor:** Play the selected track in the app (e.g. with `just_audio`) in sync with the video so the user hears it while editing.  
   - **In export:** 0.3.0 cannot mix that track into the file. Options:
     - Keep passing music + volumes in `editData` and mix audio **when uploading** (e.g. backend or a separate step with ffmpeg), or
     - Upgrade to a newer pro_video_editor version if it adds a custom audio API.

---

## Color matrix format (for `colorMatrixList`)

- **Flutter** `ColorFilter.matrix`: 20 values, row-major (4×5).
- **pro_video_editor** expects: `List<List<double>>`, e.g. one matrix = one list of 20 numbers.
- Example (single identity-like matrix):

```dart
colorMatrixList: [
  [
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ],
],
```

You can copy the same 20 values from your existing `ColorFilter.matrix` (e.g. for Vintage, B&W) into that list.

---

## Files checked (pub cache)

- `lib/core/models/video/render_video_model.dart` – full `RenderVideoModel` API
- `lib/core/models/video/editor_video_model.dart` – `EditorVideo.file()`, etc.
- `lib/core/models/video/export_transform_model.dart` – `ExportTransform`
- Android/iOS native code – only `inputPath`, `imageBytes`, `enableAudio`, `playbackSpeed`, `startTime`, `endTime`, `colorMatrixList`, `blur`, `bitrate`, `scaleX`, `scaleY`, transform fields; **no custom audio**.
