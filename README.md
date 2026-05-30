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

Backend-oriented stretch items such as Redis infrastructure, production OCR/cloud fallback, delivery infrastructure, and payment webhooks are outside this Flutter app.

## Verification

```sh
flutter analyze
flutter test
flutter build macos --debug
```
