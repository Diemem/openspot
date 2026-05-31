# ✅ OpenSpot Environment Setup Checklist

Use this checklist to set up your deployment environments correctly.

## 📋 Pre-Setup Requirements

- [ ] Flutter SDK installed (3.0.0 or higher)
- [ ] Dart SDK installed
- [ ] Git installed and configured
- [ ] Supabase account created
- [ ] Code editor (VS Code recommended)

---

## 🗄️ Step 1: Create Supabase Projects

### Development Project
- [ ] Go to [Supabase Dashboard](https://supabase.com/dashboard)
- [ ] Click "New Project"
- [ ] Name: `openspot-dev`
- [ ] Database Password: (save securely)
- [ ] Region: Choose closest to your location
- [ ] Wait for project to be ready
- [ ] Copy Project URL: `https://xxx.supabase.co`
- [ ] Copy Anon Key: Settings → API → anon/public key

### Staging Project
- [ ] Create new project
- [ ] Name: `openspot-staging`
- [ ] Database Password: (save securely)
- [ ] Same region as development
- [ ] Copy Project URL
- [ ] Copy Anon Key

### Production Project
- [ ] Create new project
- [ ] Name: `openspot-production`
- [ ] Database Password: (save securely - VERY IMPORTANT)
- [ ] Same region as others
- [ ] Copy Project URL
- [ ] Copy Anon Key

---

## 📝 Step 2: Configure Environment Files

### Development Environment
- [ ] Copy `.env.example` to `.env.development`
- [ ] Open `.env.development`
- [ ] Set `SUPABASE_URL` to dev project URL
- [ ] Set `SUPABASE_ANON_KEY` to dev anon key
- [ ] Set `GEMINI_API_KEY` (if using AI features)
- [ ] Save file

### Staging Environment
- [ ] Copy `.env.example` to `.env.staging`
- [ ] Open `.env.staging`
- [ ] Set `SUPABASE_URL` to staging project URL
- [ ] Set `SUPABASE_ANON_KEY` to staging anon key
- [ ] Set `GEMINI_API_KEY` (different from dev)
- [ ] Save file

### Production Environment
- [ ] Copy `.env.example` to `.env.production`
- [ ] Open `.env.production`
- [ ] Set `SUPABASE_URL` to production project URL
- [ ] Set `SUPABASE_ANON_KEY` to production anon key
- [ ] Set `GEMINI_API_KEY` (different from staging)
- [ ] Save file
- [ ] **Store production credentials in password manager**

---

## 🗃️ Step 3: Run Database Migrations

### Development Database
- [ ] Open Supabase Dashboard → openspot-dev
- [ ] Go to SQL Editor
- [ ] Run `add_caretaker_agency_system.sql`
- [ ] Run `update_caretaker_invitation_system.sql`
- [ ] Run `add_notifications_system.sql`
- [ ] Run `update_notifications_system.sql`
- [ ] Run `ensure_sub_role_column.sql`
- [ ] Verify all tables created (profiles, properties, agencies, etc.)

### Staging Database
- [ ] Open Supabase Dashboard → openspot-staging
- [ ] Go to SQL Editor
- [ ] Run all migration files (same order as dev)
- [ ] Verify all tables created

### Production Database
- [ ] Open Supabase Dashboard → openspot-production
- [ ] Go to SQL Editor
- [ ] Run all migration files (same order)
- [ ] Verify all tables created
- [ ] **Enable automatic backups** (Settings → Database → Backups)

---

## 🔐 Step 4: Configure Security

### Row Level Security (All Environments)
- [ ] Enable RLS on `profiles` table
- [ ] Enable RLS on `properties` table
- [ ] Enable RLS on `agencies` table
- [ ] Enable RLS on `agency_clients` table
- [ ] Enable RLS on `agency_staff` table
- [ ] Enable RLS on `caretakers` table
- [ ] Enable RLS on `notifications` table
- [ ] Enable RLS on `property_activity_log` table

### API Keys
- [ ] Development keys have usage limits set
- [ ] Staging keys have usage limits set
- [ ] Production keys monitored for usage
- [ ] All keys stored securely (not in code)

---

## 🧪 Step 5: Test Each Environment

### Test Development
```bash
flutter clean
flutter pub get
flutter run -t lib/main_development.dart
```
- [ ] App launches successfully
- [ ] Can create account
- [ ] Can sign in
- [ ] Can view properties
- [ ] No console errors
- [ ] Environment banner shows "OpenSpot Dev"

### Test Staging
```bash
flutter run -t lib/main_staging.dart
```
- [ ] App launches successfully
- [ ] Different database than dev (create test account)
- [ ] All features work
- [ ] Environment banner shows "OpenSpot Staging"

### Test Production Build
```bash
flutter build apk -t lib/main_production.dart --release
```
- [ ] Build completes without errors
- [ ] APK created successfully
- [ ] Install APK on test device
- [ ] App launches
- [ ] No debug banner visible
- [ ] Connects to production database

---

## 📱 Step 6: Platform-Specific Setup

### Android
- [ ] Update `android/app/build.gradle` with correct package name
- [ ] Set up signing keys for release builds
- [ ] Configure ProGuard rules if needed
- [ ] Test on multiple Android versions

### iOS (if applicable)
- [ ] Update `ios/Runner/Info.plist`
- [ ] Configure signing in Xcode
- [ ] Set up provisioning profiles
- [ ] Test on multiple iOS versions

---

## 🚀 Step 7: Deployment Preparation

### Development
- [ ] Team has access to dev Supabase project
- [ ] Development environment documented
- [ ] Local development guide created

### Staging
- [ ] QA team has access to staging environment
- [ ] Test data populated
- [ ] Staging URL shared with stakeholders
- [ ] Testing procedures documented

### Production
- [ ] Production credentials secured
- [ ] Backup strategy implemented
- [ ] Monitoring tools configured
- [ ] Rollback plan documented
- [ ] Incident response plan created
- [ ] Support team trained

---

## 📊 Step 8: Monitoring Setup

### Development
- [ ] Console logging enabled
- [ ] Error tracking configured

### Staging
- [ ] Analytics enabled
- [ ] Crash reporting enabled
- [ ] Performance monitoring active

### Production
- [ ] Analytics enabled
- [ ] Crash reporting enabled
- [ ] Performance monitoring active
- [ ] Uptime monitoring configured
- [ ] Alert notifications set up
- [ ] Usage dashboard created

---

## 📚 Step 9: Documentation

- [ ] Team trained on environment workflow
- [ ] Deployment guide reviewed
- [ ] Emergency contacts documented
- [ ] Runbook created for common issues
- [ ] Architecture diagram updated

---

## ✅ Final Verification

- [ ] All three environments working independently
- [ ] Each environment uses different database
- [ ] No cross-environment data leakage
- [ ] All credentials secured
- [ ] Team knows how to switch environments
- [ ] Deployment process tested end-to-end
- [ ] Rollback procedure tested

---

## 🎉 You're Ready!

Once all items are checked, you're ready to start developing with confidence!

### Quick Reference

**Development**: `flutter run -t lib/main_development.dart`  
**Staging**: `flutter run -t lib/main_staging.dart`  
**Production**: `flutter build apk -t lib/main_production.dart --release`

### Need Help?

- 📖 Read [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions
- 🌍 Check [ENVIRONMENTS.md](ENVIRONMENTS.md) for overview
- 🔄 Review [docs/environment-workflow.md](docs/environment-workflow.md) for workflow

---

**Last Updated**: June 1, 2026
