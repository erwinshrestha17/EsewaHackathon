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

Other generated targets are available too:

```sh
flutter run -d chrome
flutter run -d ios
flutter run -d android
```

## Implemented Scope

- P0: production signup/login with OTP and M-PIN, profile data, connection requests and safety actions, groups, roles, manual expenses, equal and exact splits, balances, settlement suggestions, verified eSewa settlement confirmation, direct gifts, activity logs, and Saving Circle ledger.
- P1: privacy controls, percentage/share/item splits, editable and voidable unlocked expenses, controlled receipt parser, gift pools, interactive Saving Circle creation/acceptance/schedule/contribution payment, settlement nudges, personal activity, and CSV statement export.
- P2: Flutter cross-platform app, local cache projection, smart item assignment defaults, emergency Saving Circle exit workflow, admin review surfaces, analytics dashboard, and multi-group batch settlement for the current user.
- P3: no P3 items are defined in the PRD.

Redis-backed session caching and Twilio OTP delivery are implemented in the bundled backend. Production OCR/cloud fallback, delivery infrastructure, and payment webhooks remain outside this app.

## Verification

```sh
flutter analyze
flutter test
flutter build macos --debug
```
