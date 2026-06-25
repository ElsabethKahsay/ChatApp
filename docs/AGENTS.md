# Session Notes

## iOS Build Setup (required for IPA)
```bash
# 1. Install Xcode from Mac App Store first, then:
sudo gem install cocoapods
cd flutter_app/ios
pod install
cd ..
flutter build ios --release --no-codesign  # or --release for signed
```

## Android Build
```bash
cd flutter_app
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Server
```bash
cd server
node src/index.js
# Requires: MongoDB running, .env with JWT_SECRET set
```

## Tests
```bash
cd flutter_app
flutter test
flutter analyze
```
