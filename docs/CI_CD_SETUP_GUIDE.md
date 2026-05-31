# 🔄 CI/CD Setup Guide for OpenSpot

This guide will help you implement automated CI/CD pipeline to reach 80-90% of Big Tech deployment capabilities.

## 🎯 What We'll Achieve

- ✅ Automated testing on every commit
- ✅ Automated builds for staging and production
- ✅ Automated deployment to Firebase App Distribution
- ✅ Gradual rollout to Google Play Store
- ✅ Crash monitoring and alerts
- ✅ Runtime feature flags

**Time to Implement**: 2-3 weeks  
**Cost**: $0-50/month (can be completely free)

---

## Phase 1: GitHub Actions CI/CD (Week 1)

### Step 1: Create GitHub Actions Workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  # Job 1: Run tests
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Analyze code
        run: flutter analyze
      
      - name: Run tests
        run: flutter test
      
      - name: Check formatting
        run: dart format --set-exit-if-changed .

  # Job 2: Build staging APK
  build-staging:
    name: Build Staging APK
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build staging APK
        run: flutter build apk -t lib/main_staging.dart
      
      - name: Upload APK artifact
        uses: actions/upload-artifact@v3
        with:
          name: staging-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  # Job 3: Build production APK
  build-production:
    name: Build Production APK
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build production APK
        run: flutter build apk -t lib/main_production.dart --release
      
      - name: Build App Bundle
        run: flutter build appbundle -t lib/main_production.dart --release
      
      - name: Upload APK artifact
        uses: actions/upload-artifact@v3
        with:
          name: production-apk
          path: build/app/outputs/flutter-apk/app-release.apk
      
      - name: Upload App Bundle artifact
        uses: actions/upload-artifact@v3
        with:
          name: production-aab
          path: build/app/outputs/bundle/release/app-release.aab
```

### Step 2: Add Branch Protection Rules

1. Go to GitHub repository → Settings → Branches
2. Add rule for `main` branch:
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Select "test" as required check
3. Add rule for `develop` branch (same settings)

**Result**: No code can be merged without passing tests!

---

## Phase 2: Firebase Integration (Week 1-2)

### Step 1: Set Up Firebase Project

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
cd openspot
firebase init
# Select: Crashlytics, Remote Config, App Distribution
```

### Step 2: Add Firebase to Flutter

Update `pubspec.yaml`:

```yaml
dependencies:
  # Add these
  firebase_core: ^2.24.0
  firebase_crashlytics: ^3.4.0
  firebase_remote_config: ^4.3.0
  firebase_analytics: ^10.7.0
```

### Step 3: Initialize Firebase in App

Update `lib/core/config/firebase_config.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    // Initialize Firebase
    await Firebase.initializeApp();
    
    // Set up Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    // Initialize Remote Config
    await _initializeRemoteConfig();
  }
  
  static Future<void> _initializeRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    
    // Set default values
    await remoteConfig.setDefaults({
      'enable_new_agency_dashboard': false,
      'enable_ai_property_description': false,
      'min_app_version': '1.0.0',
      'maintenance_mode': false,
    });
    
    await remoteConfig.fetchAndActivate();
  }
}
```

Update `lib/main_production.dart`:

```dart
import 'core/config/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first
  await FirebaseConfig.initialize();
  
  // Then initialize environment
  await EnvironmentConfig.initialize(environment: Environment.production);
  
  // Rest of initialization...
}
```

---

## Phase 3: Runtime Feature Flags (Week 2)

### Create Feature Flag Manager

Create `lib/core/config/feature_flags.dart`:

```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';

class FeatureFlags {
  static final _remoteConfig = FirebaseRemoteConfig.instance;
  
  // Feature flag getters
  static bool get enableNewAgencyDashboard => 
      _remoteConfig.getBool('enable_new_agency_dashboard');
  
  static bool get enableAIPropertyDescription => 
      _remoteConfig.getBool('enable_ai_property_description');
  
  static String get minAppVersion => 
      _remoteConfig.getString('min_app_version');
  
  static bool get maintenanceMode => 
      _remoteConfig.getBool('maintenance_mode');
  
  // Refresh feature flags
  static Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      print('Failed to fetch remote config: $e');
    }
  }
  
  // Check if app version is supported
  static bool isAppVersionSupported(String currentVersion) {
    // Compare versions
    return _compareVersions(currentVersion, minAppVersion) >= 0;
  }
  
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.parse).toList();
    final v2Parts = v2.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0;
  }
}
```

### Use Feature Flags in Code

```dart
// In agency_dashboard_screen.dart
Widget build(BuildContext context) {
  // Check feature flag
  if (FeatureFlags.enableNewAgencyDashboard) {
    return NewAgencyDashboard();
  } else {
    return OldAgencyDashboard();
  }
}

// In property creation screen
if (FeatureFlags.enableAIPropertyDescription) {
  // Show AI-powered description generator
  showAIDescriptionButton();
}

// In app startup
if (FeatureFlags.maintenanceMode) {
  return MaintenanceScreen();
}
```

### Configure in Firebase Console

1. Go to Firebase Console → Remote Config
2. Add parameters:
   ```
   enable_new_agency_dashboard: false (default)
   enable_ai_property_description: false (default)
   min_app_version: "1.0.0"
   maintenance_mode: false
   ```
3. Create conditions for gradual rollout:
   ```
   Condition: "5% of users"
   - Random percentile <= 5
   - Set enable_new_agency_dashboard = true
   ```

**Result**: You can now toggle features without app updates!

---

## Phase 4: Automated Deployment (Week 2-3)

### Step 1: Firebase App Distribution

Update `.github/workflows/ci.yml`:

```yaml
  # Add this job
  deploy-to-firebase:
    name: Deploy to Firebase App Distribution
    needs: build-staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Download APK
        uses: actions/download-artifact@v3
        with:
          name: staging-apk
      
      - name: Deploy to Firebase App Distribution
        uses: wzieba/Firebase-Distribution-Github-Action@v1
        with:
          appId: ${{ secrets.FIREBASE_APP_ID }}
          token: ${{ secrets.FIREBASE_TOKEN }}
          groups: testers
          file: app-release.apk
          releaseNotes: "Automated staging build from commit ${{ github.sha }}"
```

### Step 2: Google Play Staged Rollout

Create `fastlane/Fastfile`:

```ruby
default_platform(:android)

platform :android do
  desc "Deploy to Google Play Internal Testing"
  lane :internal do
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Promote to Open Testing (5% rollout)"
  lane :beta_5 do
    upload_to_play_store(
      track: 'beta',
      rollout: '0.05',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Increase rollout to 25%"
  lane :beta_25 do
    upload_to_play_store(
      track: 'beta',
      rollout: '0.25',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Increase rollout to 50%"
  lane :beta_50 do
    upload_to_play_store(
      track: 'beta',
      rollout: '0.50',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Full production rollout"
  lane :production do
    upload_to_play_store(
      track: 'production',
      rollout: '1.0',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
```

### Step 3: Deployment Process

```bash
# 1. Deploy to internal testing (automated)
fastlane internal

# 2. After QA approval, start gradual rollout
fastlane beta_5

# 3. Monitor for 24 hours, check:
#    - Crash rate < 1%
#    - No critical bugs
#    - Performance OK

# 4. If OK, increase rollout
fastlane beta_25

# 5. Monitor for 24 hours

# 6. If OK, increase rollout
fastlane beta_50

# 7. Monitor for 12 hours

# 8. If OK, full production
fastlane production
```

---

## Phase 5: Monitoring & Alerts (Week 3)

### Step 1: Set Up Crashlytics Alerts

1. Go to Firebase Console → Crashlytics
2. Set up alerts:
   - Crash rate > 1% → Email alert
   - New crash type → Slack notification
   - Regression detected → PagerDuty alert

### Step 2: Add Custom Logging

```dart
// Log custom events
FirebaseCrashlytics.instance.log('User viewed property: $propertyId');

// Set user identifier
FirebaseCrashlytics.instance.setUserIdentifier(userId);

// Log custom keys
FirebaseCrashlytics.instance.setCustomKey('environment', 'production');
FirebaseCrashlytics.instance.setCustomKey('user_role', userRole);

// Record non-fatal errors
try {
  await riskyOperation();
} catch (e, stack) {
  FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
}
```

### Step 3: Performance Monitoring

Add to `pubspec.yaml`:

```yaml
dependencies:
  firebase_performance: ^0.9.3
```

Add monitoring:

```dart
import 'package:firebase_performance/firebase_performance.dart';

// Monitor network requests
final metric = FirebasePerformance.instance.newHttpMetric(
  'https://api.example.com/properties',
  HttpMethod.Get,
);
await metric.start();
final response = await http.get(url);
metric.setHttpResponseCode(response.statusCode);
metric.setResponseContentType(response.headers['content-type']);
await metric.stop();

// Monitor custom traces
final trace = FirebasePerformance.instance.newTrace('load_properties');
await trace.start();
await loadProperties();
await trace.stop();
```

---

## 📊 Success Metrics

After implementation, you should see:

### **Before CI/CD:**
- Manual testing: 2-4 hours
- Build time: 30 minutes
- Deployment time: 1-2 hours
- Bug detection: Days after release
- Rollback time: 2-4 hours
- **Total time to production: 1-2 days**

### **After CI/CD:**
- Automated testing: 10 minutes
- Build time: 15 minutes (automated)
- Deployment time: 30 minutes (automated)
- Bug detection: Minutes (crash alerts)
- Rollback time: 5 minutes (feature flags)
- **Total time to production: 2-3 hours**

### **Improvement:**
- ⚡ **10x faster** deployment
- 🛡️ **90% fewer** production bugs
- 🚀 **Zero downtime** updates
- 📊 **Real-time** monitoring
- 🔄 **Instant** rollback capability

---

## 💰 Cost Breakdown

| Service | Free Tier | Paid Tier |
|---------|-----------|-----------|
| GitHub Actions | 2,000 min/month | $0.008/min |
| Firebase Crashlytics | Unlimited | Free |
| Firebase Remote Config | Unlimited | Free |
| Firebase App Distribution | Unlimited | Free |
| Google Play Console | One-time $25 | - |
| **Total** | **$0-25** | **$50-100/month** |

---

## 🎯 Next Steps

1. **Week 1**: Set up GitHub Actions CI/CD
2. **Week 2**: Add Firebase (Crashlytics, Remote Config)
3. **Week 3**: Implement staged rollout and monitoring
4. **Week 4**: Test entire pipeline end-to-end

After this, you'll be at **85-90% of Big Tech deployment capabilities**! 🚀

---

## 📚 Additional Resources

- [GitHub Actions for Flutter](https://docs.github.com/en/actions)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Fastlane for Android](https://docs.fastlane.tools/getting-started/android/setup/)
- [Google Play Staged Rollouts](https://support.google.com/googleplay/android-developer/answer/6346149)
