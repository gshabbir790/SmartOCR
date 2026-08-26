Tesseract traineddata files used by Smart OCR:

eng.traineddata
urd_naw.traineddata   <- primary Urdu Nastaliq model
urd.traineddata      <- official high-accuracy Urdu fallback
ara.traineddata
hin.traineddata

The binary models are intentionally not committed to the repository. GitHub
Actions downloads them automatically before every release build.

The specialised `urd_naw` model is a user-contributed Tesseract model trained
for Urdu Nastaliq and is the primary Urdu OCR model in this app. The official
`tessdata_best` Urdu model is retained as a fallback for non-Nastaliq Urdu.

The plugin reads `assets/tessdata_config.json` to determine which models are
available. Do not remove `urd_naw.traineddata` from that configuration.
