# Smart OCR — Flutter Android

Production-oriented, simple OCR scanner focused on the critical flow:

**Gallery → Share → Smart OCR → automatic OCR → result**

Also supports camera capture, gallery multi-select, editable OCR, history, Urdu/RTL text, and an optional secure AI backend.

## Existing-project inspection

This was designed to extend the existing `Admission-Studio-pro` Flutter codebase rather than depend on its admission-photo workflow. The existing repository is Flutter 3.x, already has `camera`, `image_picker`, `image`, `path_provider`, Hive and permission handling. The OCR feature uses those foundations and adds a dedicated OCR feature boundary.

## Important OCR note

Google ML Kit's Flutter text-recognition package currently supports Latin, Chinese, Devanagari, Japanese and Korean scripts, not Urdu/Arabic. For Urdu/Arabic this build uses Tesseract, which requires the corresponding trained-data files. Add `eng.traineddata`, `urd.traineddata`, `ara.traineddata`, and `hin.traineddata` to `assets/tessdata/`. Tesseract supports 100+ languages.

For production, use `tessdata_fast` for speed or `tessdata_best` for accuracy and keep only the languages your app needs.

## Setup

1. Install Flutter 3.44+ / Dart 3.12+.
2. Put Tesseract traineddata in `assets/tessdata/`.
3. Run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Android Share Sheet

`AndroidManifest.xml` declares both `ACTION_SEND` and `ACTION_SEND_MULTIPLE` for `image/*`. `MainActivity.kt` accepts `content://` URIs, copies them into app cache, and forwards them to Flutter. `singleTop` plus `onNewIntent()` handles warm starts; the same code handles cold starts.

Test:

```bash
adb shell am start -a android.intent.action.SEND -t image/jpeg --stream content://...
adb shell am start -a android.intent.action.SEND_MULTIPLE -t image/* --stream content://...
```

The easiest real-world test is Android Gallery/Google Photos → select image(s) → Share → Smart OCR.

## Security

No provider API key belongs in Flutter. Set the backend URL in the app configuration and keep provider secrets in Cloudflare Worker environment variables. The example Worker validates MIME type, size and request shape.

## AI backend

Set `AI_BACKEND_URL` only to your own HTTPS endpoint. The Flutter app sends OCR text and optional image bytes only when the user explicitly invokes an online AI action. Basic OCR/history remains local.

## Release signing

Configure `android/key.properties` and a release signing config before Play Store upload. Never commit the keystore or key properties.
