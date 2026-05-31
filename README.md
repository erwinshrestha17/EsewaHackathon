# Sajha Kharcha Flutter App

Sajha Kharcha is a responsive Flutter app for Cache Flow's Challenge 10 PRD: social financial connections, group expenses, split modes, transparent balances, real eSewa settlements, gift cards, group gift pools, and Saving Circle.

The app now uses the bundled Express backend for production-style signup/login. Signup verifies a Nepal mobile number with Twilio OTP, login uses mobile number + M-PIN, and the Flutter client stores access/refresh tokens in secure storage.

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
redis-server
```

In another terminal:

```sh
cd backend
npm install
npm run dev
```

In another terminal:

```sh
flutter pub get
flutter run -d macos --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
```

Realtime UI refresh uses the backend WebSocket endpoint at `/api/app/ws`; no external realtime provider configuration is required.

Other generated targets are available too:

```sh
flutter run -d chrome --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
flutter run -d ios
flutter run -d android --dart-define=BACKEND_API_BASE_URL=http://10.0.2.2:3000
```

For Android Studio emulator runs, add this to the Flutter run configuration's
additional run args:

```sh
--dart-define=BACKEND_API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator alias for the development machine's
localhost. Do not use `127.0.0.1` for the Android emulator unless the backend is
running inside the emulator itself.

For Flutter web on Linux VMs, containers, or another machine on your network,
`127.0.0.1` must be the backend as seen by the browser. If the backend runs on a
different host, start it with `HOST=0.0.0.0` and use that host's reachable IP:

```sh
HOST=0.0.0.0 npm run dev
flutter run -d chrome --dart-define=BACKEND_API_BASE_URL=http://192.168.1.25:3000
```

## Implemented Scope

- P0: production signup/login with OTP and M-PIN, profile data, connection requests and safety actions, groups, roles, manual expenses, equal and exact splits, balances, settlement suggestions, verified eSewa settlement confirmation, direct gifts, activity logs, and Saving Circle ledger.
- P1: privacy controls, percentage/share/item splits, editable and voidable unlocked expenses, controlled receipt parser, gift pools, interactive Saving Circle creation/acceptance/schedule/contribution payment, settlement nudges, personal activity, and CSV statement export.
- P2: Flutter cross-platform app, local cache projection, smart item assignment defaults, emergency Saving Circle exit workflow, admin review surfaces, analytics dashboard, and multi-group batch settlement for the current user.
- P3: no P3 items are defined in the PRD.

Redis-backed session caching, Twilio OTP delivery, backend-backed CUD actions, and WebSocket invalidation are implemented in the bundled backend. Bill OCR now runs on-device; production cloud OCR fallback, delivery infrastructure, and payment webhooks remain outside this app.

## Verification

```sh
flutter analyze
flutter test
flutter build macos --debug
```
