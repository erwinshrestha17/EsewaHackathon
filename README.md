# Sajha Kharcha Flutter App

Sajha Kharcha is a responsive Flutter app for Cache Flow's Challenge 10 PRD: social financial connections, group expenses, split modes, transparent balances, real eSewa settlements, gift cards, group gift pools, and Saving Circle.

This repository intentionally implements the application locally in Flutter only. It does not call or modify a backend.

## eSewa Setup

Payments use `esewa_flutter` and default to the eSewa UAT credentials:

```sh
flutter run -d android
```

For production credentials, pass dart defines:

```sh
flutter run -d android \
  --dart-define=ESEWA_ENV=live \
  --dart-define=ESEWA_PRODUCT_CODE=your_merchant_code \
  --dart-define=ESEWA_SECRET_KEY=your_secret_key \
  --dart-define=ESEWA_SUCCESS_URL=https://your.domain/success \
  --dart-define=ESEWA_FAILURE_URL=https://your.domain/failure
```

## Bill Scanning (on-device OCR)

Itemized bills are scanned **on-device** with [`flutter_paddle_ocr`](https://pub.dev/packages/flutter_paddle_ocr)
(PaddleOCR / Paddle Lite) — no backend or network OCR service. From an expense
group, tap **Capture bill** (camera) or **Upload** (gallery); the recognized
text is parsed into items, quantities, service charge, VAT, and discount and
pre-filled into the Manual Entry sheet for review.

The PP-OCRv2 Paddle Lite model files (~8 MB) download and cache on the device
the first time you scan; subsequent scans are offline.

Platform requirements (from the Paddle Lite v2.10 runtime):

- **Android:** arm64-v8a device, **minSdk 24**, **NDK r25c** (`25.2.9519653`).
  The first Android build downloads the Paddle Lite + OpenCV native archives
  (~225 MB). 32-bit and x86 emulators are not supported.
- **iOS:** arm64 device, **iOS 13+** (the simulator is not supported).
- **Web:** uses `paddleocr-js` (PP-OCRv5) via `ModelSource.bundled`. This needs
  a one-time bundle in `web/` (requires Node.js); the script tag is already
  wired into `web/index.html`:

  ```sh
  TMP=$(mktemp -d)
  echo '{"name":"b","type":"module","dependencies":{"@paddleocr/paddleocr-js":"0.3.2"}}' > "$TMP/package.json"
  printf "import { PaddleOCR } from '@paddleocr/paddleocr-js';\nwindow.PaddleOCR = PaddleOCR;\n" > "$TMP/entry.js"
  (cd "$TMP" && npm install --silent)
  npx --yes esbuild "$TMP/entry.js" --bundle --format=iife --target=es2020 \
    --define:process.env.NODE_ENV='"production"' \
    --external:fs --external:path --external:crypto \
    --external:node:fs --external:node:path --external:node:crypto \
    --outfile=web/paddleocr_bundle.js
  ```

  ONNX Runtime's WASM and the PP-OCRv5 models are fetched from a CDN at runtime,
  so the first web scan needs an internet connection.

## Run on macOS

```sh
flutter pub get
flutter run -d macos
```

Other generated targets are available too:

```sh
flutter run -d chrome
flutter run -d ios
flutter run -d android
```

## Demo Users

Use the account switcher in the top bar to move between seeded eSewa-style users:

- Sita Shrestha: `9800000001`
- Arjun Karki: `9800000002`
- Maya Gurung: `9800000003`
- Nabin Rai: `9800000004`
- Laxmi Thapa: `9800000005`
- Kabir Lama: `9800000006`
- Rina Basnet: `9800000007`
- Pasang Sherpa: `9800000008`

## Implemented Scope

- P0: demo login, profile data, connection requests and safety actions, groups, roles, manual expenses, equal and exact splits, balances, settlement suggestions, verified eSewa settlement confirmation, direct gifts, activity logs, and seeded Saving Circle ledger.
- P1: privacy controls, percentage/share/item splits, editable and voidable unlocked expenses, controlled receipt parser, gift pools, interactive Saving Circle creation/acceptance/schedule/contribution payment, settlement nudges, personal activity, and CSV statement export.
- P2: Flutter cross-platform app, local cache projection, smart item assignment defaults, emergency Saving Circle exit workflow, admin review surfaces, analytics dashboard, and multi-group batch settlement for the current user.
- P3: no P3 items are defined in the PRD.

Backend-oriented stretch items such as Redis infrastructure, cloud OCR fallback, delivery infrastructure, and payment webhooks are outside this Flutter app. (Bill OCR itself now runs on-device — see "Bill Scanning" above.)

## Verification

```sh
flutter analyze
flutter test
flutter build macos --debug
```
