Place Tesseract traineddata files here:
eng.traineddata
urd.traineddata
ara.traineddata
hin.traineddata

These binary model files are intentionally not committed to the repo
(they are ~1-15MB each). The GitHub Actions workflow downloads them
automatically before every build (see .github/workflows/main.yml,
step "Download Tesseract trained data"), so APKs built via CI always
include real OCR data.

If you build locally (flutter build apk / flutter run) instead of
via CI, you must download these 4 files yourself first, e.g.:

  cd assets/tessdata
  for lang in eng urd ara hin; do
    curl -fL -o "$lang.traineddata" \
      "https://github.com/tesseract-ocr/tessdata_fast/raw/main/$lang.traineddata"
  done

Without these files present, Tesseract cannot recognize any text and
every scan will fail with "Could not process this image."

NOTE: the config file the plugin actually reads is assets/tessdata_config.json
(one directory up from this folder) — NOT a file inside assets/tessdata/.
