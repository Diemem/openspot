# 🚀 Quick Deployment Commands

## Development

```bash
# Run development environment
flutter run -t lib/main_development.dart

# Run with specific device
flutter run -t lib/main_development.dart -d <device-id>

# Hot reload is available in development
# Press 'r' to hot reload
# Press 'R' to hot restart
```

## Staging

```bash
# Run staging environment
flutter run -t lib/main_staging.dart

# Build staging APK for testing
flutter build apk -t lib/main_staging.dart

# Install staging APK on connected device
flutter install -t lib/main_staging.dart
```

## Production

```bash
# Build production APK (for direct distribution)
flutter build apk -t lib/main_production.dart --release

# Build production App Bundle (for Google Play)
flutter build appbundle -t lib/main_production.dart --release

# Build production iOS (then archive in Xcode)
flutter build ios -t lib/main_production.dart --release
```

## Useful Commands

```bash
# Clean build cache
flutter clean

# Get dependencies
flutter pub get

# Run code generation (if needed)
flutter pub run build_runner build --delete-conflicting-outputs

# Check for issues
flutter doctor

# List connected devices
flutter devices

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Environment Switching

To switch environments, simply use the appropriate entry point:

- **Development**: `-t lib/main_development.dart`
- **Staging**: `-t lib/main_staging.dart`
- **Production**: `-t lib/main_production.dart`

## Build Outputs

After building, find your files here:

- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`
- **iOS**: `build/ios/iphoneos/Runner.app`
