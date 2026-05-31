# 🌍 OpenSpot Environment Configuration

## Quick Start

OpenSpot now supports **three deployment environments** to ensure safe development and deployment:

### 🔧 Development
- **Purpose**: Local development and testing
- **Run**: `flutter run -t lib/main_development.dart`
- **Config**: `.env.development`

### 🧪 Staging  
- **Purpose**: Pre-production testing and QA
- **Run**: `flutter run -t lib/main_staging.dart`
- **Config**: `.env.staging`

### 🚀 Production
- **Purpose**: Live production app
- **Build**: `flutter build apk -t lib/main_production.dart --release`
- **Config**: `.env.production`

## Setup Steps

1. **Create three Supabase projects** (dev, staging, production)
2. **Copy environment files**:
   ```bash
   cp .env.example .env.development
   cp .env.example .env.staging
   cp .env.example .env.production
   ```
3. **Fill in credentials** for each environment
4. **Run migrations** on each Supabase project
5. **Start developing**!

## Key Features

✅ **Separate databases** for each environment  
✅ **Environment-specific configuration**  
✅ **Feature flags** (debug logging, analytics, crash reporting)  
✅ **Easy switching** between environments  
✅ **Safe deployment** workflow (dev → staging → production)  

## Configuration Files

| File | Purpose | Committed to Git? |
|------|---------|-------------------|
| `.env.example` | Template with placeholders | ✅ Yes |
| `.env.development` | Development credentials | ❌ No |
| `.env.staging` | Staging credentials | ❌ No |
| `.env.production` | Production credentials | ❌ No |

## Entry Points

| File | Environment | Use Case |
|------|-------------|----------|
| `lib/main.dart` | Development (default) | Quick development |
| `lib/main_development.dart` | Development | Explicit dev environment |
| `lib/main_staging.dart` | Staging | Testing before production |
| `lib/main_production.dart` | Production | Release builds |

## Environment Variables

Each environment file supports:

```env
# App Configuration
ENVIRONMENT=development|staging|production
APP_NAME=OpenSpot Dev|OpenSpot Staging|OpenSpot

# Supabase (different project per environment)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# AI Services (optional)
OPENAI_API_KEY=your-key
GEMINI_API_KEY=your-key

# Feature Flags
ENABLE_DEBUG_LOGGING=true|false
ENABLE_ANALYTICS=true|false
ENABLE_CRASH_REPORTING=true|false
```

## Best Practices

1. **Never commit** environment files with real credentials
2. **Always test** in staging before production
3. **Use different API keys** for each environment
4. **Backup production** database before migrations
5. **Monitor usage** and costs across environments

## Documentation

- 📖 **Full Guide**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- 🚀 **Quick Commands**: See [scripts/deploy.md](scripts/deploy.md)

---

**Need Help?** Check the deployment documentation or contact the development team.
