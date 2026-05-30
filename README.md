# Sangai Flutter App

Sangai is a responsive Flutter prototype for Cache Flow's Challenge 10 PRD: social financial connections, group expenses, split modes, transparent balances, mock eSewa settlements, gift cards, group gift pools, and Savings Circle.

This repository intentionally implements the application locally in Flutter only. It does not call or modify a backend.

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

- P0: demo login, profile data, connection requests and safety actions, groups, roles, manual expenses, equal and exact splits, balances, settlement suggestions, idempotent mock eSewa settlement confirmation, direct gifts, activity logs, and seeded Savings Circle ledger.
- P1: privacy controls, percentage/share/item splits, editable and voidable unlocked expenses, controlled receipt parser, gift pools, interactive Savings Circle creation/acceptance/schedule/contribution payment, settlement nudges, personal activity, and CSV statement export.
- P2: Flutter cross-platform app, simulated push UX, local cache projection, smart item assignment defaults, emergency Savings Circle exit workflow, admin review surfaces, analytics dashboard, and multi-group batch settlement for the current user.
- P3: no P3 items are defined in the PRD.

Backend-oriented stretch items such as Redis infrastructure, production OCR/cloud fallback, real push delivery, and payment webhooks are represented as frontend-safe prototype surfaces only.

## Verification

```sh
flutter analyze
flutter test
flutter build macos --debug
```
