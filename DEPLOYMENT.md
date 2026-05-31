# 🚀 OpenSpot Deployment Guide

This guide explains how to deploy OpenSpot across different environments.

## 📋 Table of Contents
- [Environment Overview](#environment-overview)
- [Setup Instructions](#setup-instructions)
- [Running Different Environments](#running-different-environments)
- [Building for Release](#building-for-release)
- [Supabase Setup](#supabase-setup)
- [Best Practices](#best-practices)

---

## 🌍 Environment Overview

OpenSpot supports three deployment environments:

| Environment | Purpose | Debug Mode | Analytics | Crash Reporting |
|------------|---------|------------|-----------|-----------------|
| **Development** | Local development & testing | ✅ Enabled | ❌ Disabled | ❌ Disabled |
| **Staging** | Pre-production testing & QA | ✅ Enabled | ✅ Enabled | ✅ Enabled |
| **Production** | Live production app | ❌ Disabled | ✅ Enabled | ✅ Enabled |

---

## 🛠️ Setup Instructions

### 1. Create Supabase Projects

You need **three separate Supabase projects**:

1. **Development Project**: For local development
   - Go to [Supabase Dashboard](https://supabase.com/dashboard)
   - Create a new project named `openspot-dev`
   - Copy the URL and anon key

2. **Staging Project**: For testing
   - Create a new project named `openspot-staging`
   - Copy the URL and anon key

3. **Production Project**: For live app
   - Create a new project named `openspot-production`
   - Copy the URL and anon key

### 2. Configure Environment Files

Copy the example files and fill in your credentials:

```bash
# Development
cp .env.example .env.development
# Edit .env.development with your dev Supabase credentials

# Staging
cp .env.example .env.staging
# Edit .env.staging with your staging Supabase credentials

# Production
cp .env.example .env.production
# Edit .env.production with your production Supabase credentials
```

### 3. Run Database Migrations

Run migrations on **each Supabase project**:

```bash
# For each environment, run all SQL files in supabase/migrations/
# in the Supabase SQL Editor
```

**Migration files to run (in order):**
1. `add_caretaker_agency_system.sql`
2. `update_caretaker_invitation_system.sql`
3. `add_notifications_system.sql`
4. `update_notifications_system.sql`
5. `ensure_sub_role_column.sql`

---

## 🏃 Running Different Environments

### Development Environment

```bash
# Run on emulator/device
flutter run -t lib/main_development.dart

# Or use the default main.dart (set to development by default)
flutter run
```

### Staging Environment

```bash
# Run on emulator/device
flutter run -t lib/main_staging.dart

# Build APK for testing
flutter build apk -t lib/main_staging.dart
```

### Production Environment

```bash
# Build release APK
flutter build apk -t lib/main_production.dart --release

# Build release iOS
flutter build ios -t lib/main_production.dart --release

# Build App Bundle for Google Play
flutter build appbundle -t lib/main_production.dart --release
```

---

## 📦 Building for Release

### Android Release Build

```bash
# Build APK (for direct distribution)
flutter build apk -t lib/main_production.dart --release

# Build App Bundle (for Google Play Store)
flutter build appbundle -t lib/main_production.dart --release

# Output locations:
# APK: build/app/outputs/flutter-apk/app-release.apk
# Bundle: build/app/outputs/bundle/release/app-release.aab
```

### iOS Release Build

```bash
# Build iOS app
flutter build ios -t lib/main_production.dart --release

# Then open in Xcode to archive and upload to App Store
open ios/Runner.xcworkspace
```

---

## 🗄️ Supabase Setup

### Development Database
- Use for local testing
- Can reset/wipe data frequently
- Test new features here first

### Staging Database
- Mirror of production structure
- Use for QA and testing
- Should have realistic test data

### Production Database
- Live user data
- **Never test here directly**
- Always test in staging first

### Row Level Security (RLS)

Ensure RLS policies are enabled on all tables in **all environments**:

```sql
-- Example: Enable RLS on profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create policies for each table
-- (Run the same policies in dev, staging, and production)
```

---

## ✅ Best Practices

### 1. Development Workflow

```
Development → Staging → Production
```

1. **Develop** new features in development environment
2. **Test** thoroughly in staging environment
3. **Deploy** to production only after staging approval

### 2. Database Migrations

- Test migrations in **development** first
- Apply to **staging** for QA testing
- Apply to **production** during maintenance window
- **Always backup production database before migrations**

### 3. Environment Variables

- **Never commit** `.env`, `.env.development`, `.env.staging`, or `.env.production`
- Only commit `.env.example` with placeholder values
- Store production secrets securely (use a password manager)

### 4. API Keys

- Use **different API keys** for each environment
- Rotate keys if exposed
- Set usage limits on development/staging keys

### 5. Feature Flags

Use the built-in feature flags in environment files:

```env
# Enable/disable features per environment
ENABLE_DEBUG_LOGGING=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
```

### 6. Testing Before Production

**Checklist before production deployment:**

- [ ] All features tested in staging
- [ ] Database migrations tested in staging
- [ ] No console errors or warnings
- [ ] Performance tested with realistic data
- [ ] Security review completed
- [ ] Backup production database
- [ ] Rollback plan prepared

---

## 🔧 Troubleshooting

### Environment not loading

```bash
# Clean build and rebuild
flutter clean
flutter pub get
flutter run -t lib/main_development.dart
```

### Wrong environment loaded

Check the entry point file:
- `main_development.dart` → Development
- `main_staging.dart` → Staging
- `main_production.dart` → Production

### Supabase connection error

1. Verify URL and anon key in `.env.*` file
2. Check Supabase project is active
3. Verify network connection
4. Check Supabase dashboard for service status

---

## 📞 Support

For issues or questions:
- Check the [Supabase Documentation](https://supabase.com/docs)
- Review [Flutter Documentation](https://docs.flutter.dev)
- Contact the development team

---

## 🔐 Security Notes

- **Production credentials** should only be known to authorized personnel
- Use **environment-specific service accounts** where possible
- Enable **audit logging** in production Supabase project
- Regularly **rotate API keys** and credentials
- Monitor **usage and costs** across all environments

---

**Last Updated**: June 1, 2026
