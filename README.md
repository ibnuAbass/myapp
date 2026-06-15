# M-PESA Finance Tracker

Flutter app that reads M-PESA confirmation SMS from your Android inbox and tracks spending with analytics.

## Features

- Reads M-PESA SMS from sender `MPESA`
- Parses sent, received, paybill, till, withdrawal, deposit, airtime, and reversal transactions
- Home dashboard with balance, income vs expenses, and recent transactions
- Month-scoped analytics with counterparty breakdown (who you pay most, who pays you most)
- Searchable transaction history with filters

## Requirements

- Flutter 3.x
- Android device with M-PESA SMS history
- `READ_SMS` permission (Android only)

## Run

```bash
flutter pub get
flutter run
```

## Build

```bash
flutter build apk --release
```

## Download APK

[Download latest APK](https://github.com/ibnuAbass/myapp/raw/main/downloads/app-release.apk)
