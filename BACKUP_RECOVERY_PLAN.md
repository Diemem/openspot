# 🔄 Backup & Recovery Plan

**Last Updated**: June 1, 2026  
**Owner**: DevOps Team  
**Review Frequency**: Quarterly

---

## 📋 Overview

This document outlines the backup strategy, recovery procedures, and disaster recovery plan for OpenSpot.

---

## 🎯 Recovery Objectives

| Metric | Target | Current |
|--------|--------|---------|
| **RTO** (Recovery Time Objective) | < 4 hours | TBD |
| **RPO** (Recovery Point Objective) | < 24 hours | TBD |
| **Data Loss Tolerance** | < 1 hour | TBD |

---

## 💾 Backup Strategy

### 1. Database Backups (Supabase)

#### Automatic Backups
- **Frequency**: Daily at 2:00 AM UTC
- **Retention**: 7 days (Free tier) / 30 days (Pro tier)
- **Type**: Full database snapshot
- **Location**: Supabase managed storage

#### Point-in-Time Recovery (Pro tier only)
- **Enabled**: Yes (after upgrade to Pro)
- **Retention**: 7 days
- **Granularity**: 1-second precision

#### Manual Backups
- **Frequency**: Before major deployments
- **Retention**: 90 days
- **Storage**: External S3 bucket

### 2. File Storage Backups

#### User Uploads (Supabase Storage)
- **Frequency**: Daily incremental
- **Retention**: 30 days
- **Type**: Incremental snapshots
- **Location**: Supabase managed storage

#### Critical Files
- **Frequency**: Real-time replication
- **Retention**: Indefinite
- **Type**: Multi-region replication
- **Files**: Profile photos, property images, documents

### 3. Configuration Backups

#### Environment Variables
- **Frequency**: On change
- **Storage**: Encrypted in password manager (1Password/LastPass)
- **Backup**: Git repository (encrypted)

#### Database Migrations
- **Frequency**: On commit
- **Storage**: GitHub repository
- **Backup**: Multiple developer machines

---

## 🚨 Disaster Recovery Procedures

### Scenario 1: Database Corruption

**Symptoms**: Data inconsistencies, query errors, missing records

**Recovery Steps**:

1. **Assess Damage** (5 minutes)
   ```sql
   -- Check table integrity
   SELECT COUNT(*) FROM profiles;
   SELECT COUNT(*) FROM properties;
   SELECT COUNT(*) FROM notifications;
   
   -- Check for orphaned records
   SELECT COUNT(*) FROM properties WHERE landlord_id NOT IN (SELECT id FROM profiles);
   ```

2. **Stop Write Operations** (2 minutes)
   - Enable maintenance mode via feature flag
   - Set `maintenance_mode = true` in Supabase

3. **Restore from Backup** (30-60 minutes)
   ```bash
   # Via Supabase Dashboard
   1. Go to Database → Backups
   2. Select most recent valid backup
   3. Click "Restore"
   4. Confirm restoration
   
   # Via CLI (if available)
   supabase db restore --backup-id <backup-id>
   ```

4. **Verify Data Integrity** (15 minutes)
   ```sql
   -- Verify critical tables
   SELECT COUNT(*) FROM profiles;
   SELECT COUNT(*) FROM properties WHERE status = 'active';
   SELECT MAX(created_at) FROM audit_logs;
   
   -- Check relationships
   SELECT COUNT(*) FROM properties p
   LEFT JOIN profiles pr ON p.landlord_id = pr.id
   WHERE pr.id IS NULL;
   ```

5. **Resume Operations** (5 minutes)
   - Disable maintenance mode
   - Monitor error rates
   - Check user reports

**Total Time**: 1-2 hours

---

### Scenario 2: Complete Database Loss

**Symptoms**: Database unreachable, connection errors, Supabase outage

**Recovery Steps**:

1. **Confirm Outage** (5 minutes)
   - Check Supabase status page
   - Verify network connectivity
   - Check other Supabase projects

2. **Activate Disaster Recovery** (10 minutes)
   - Notify team via Slack/PagerDuty
   - Enable maintenance page
   - Communicate with users

3. **Restore from Latest Backup** (1-2 hours)
   ```bash
   # Create new Supabase project
   1. Go to Supabase Dashboard
   2. Create new project: openspot-recovery
   3. Restore from backup
   4. Run all migrations
   5. Verify data
   ```

4. **Update DNS/Configuration** (30 minutes)
   ```bash
   # Update environment variables
   SUPABASE_URL=https://new-project.supabase.co
   SUPABASE_ANON_KEY=new-anon-key
   
   # Deploy updated configuration
   git commit -m "Emergency: Update Supabase URL"
   git push
   ```

5. **Verify and Resume** (30 minutes)
   - Test critical flows
   - Monitor error rates
   - Gradual traffic restoration

**Total Time**: 3-4 hours

---

### Scenario 3: File Storage Loss

**Symptoms**: Images not loading, 404 errors on media

**Recovery Steps**:

1. **Assess Impact** (10 minutes)
   ```sql
   -- Check affected files
   SELECT COUNT(*) FROM file_uploads WHERE status = 'approved';
   SELECT COUNT(DISTINCT user_id) FROM file_uploads;
   ```

2. **Restore from Backup** (1-2 hours)
   ```bash
   # Via Supabase Dashboard
   1. Go to Storage → Backups
   2. Select backup date
   3. Restore affected buckets
   ```

3. **Verify Files** (15 minutes)
   - Check random sample of images
   - Verify file accessibility
   - Test upload functionality

**Total Time**: 1.5-2.5 hours

---

### Scenario 4: Accidental Data Deletion

**Symptoms**: User reports missing data, audit logs show deletions

**Recovery Steps**:

1. **Identify Scope** (10 minutes)
   ```sql
   -- Check audit logs
   SELECT * FROM audit_logs
   WHERE action LIKE '%delete%'
   AND created_at > NOW() - INTERVAL '1 hour'
   ORDER BY created_at DESC;
   ```

2. **Stop Further Deletions** (5 minutes)
   - Revoke permissions if needed
   - Enable maintenance mode

3. **Restore Specific Data** (30-60 minutes)
   ```sql
   -- Point-in-time recovery (Pro tier)
   -- Restore to timestamp before deletion
   
   -- OR restore from backup and extract specific records
   ```

4. **Verify Restoration** (15 minutes)
   - Check restored records
   - Verify relationships
   - Contact affected users

**Total Time**: 1-2 hours

---

## 🧪 Testing Schedule

### Monthly Tests
- [ ] Restore database from backup to test environment
- [ ] Verify data integrity
- [ ] Document restoration time
- [ ] Update procedures if needed

### Quarterly Tests
- [ ] Full disaster recovery drill
- [ ] Test all scenarios
- [ ] Update RTO/RPO metrics
- [ ] Train team on procedures

### Annual Tests
- [ ] Complete failover test
- [ ] Multi-region recovery test
- [ ] Update disaster recovery plan

---

## 📞 Emergency Contacts

### Internal Team
- **DevOps Lead**: [Name] - [Phone] - [Email]
- **CTO**: [Name] - [Phone] - [Email]
- **Database Admin**: [Name] - [Phone] - [Email]

### External Vendors
- **Supabase Support**: support@supabase.io
- **Supabase Status**: https://status.supabase.com
- **Emergency Hotline**: [If Pro tier]

---

## 📊 Backup Monitoring

### Daily Checks
- [ ] Verify backup completion
- [ ] Check backup size (should be consistent)
- [ ] Review backup logs for errors

### Weekly Checks
- [ ] Test backup restoration (sample)
- [ ] Verify backup retention policy
- [ ] Check storage usage

### Alerts
- ❌ Backup failed
- ❌ Backup size anomaly (>20% change)
- ❌ Backup older than 48 hours
- ❌ Storage quota exceeded

---

## 🔐 Security Considerations

### Backup Encryption
- ✅ All backups encrypted at rest
- ✅ Encryption keys managed by Supabase
- ✅ Access restricted to authorized personnel

### Access Control
- ✅ Backup access requires MFA
- ✅ Audit log for backup access
- ✅ Principle of least privilege

### Compliance
- ✅ GDPR: Right to erasure (backup retention)
- ✅ Data residency requirements
- ✅ Audit trail for all restorations

---

## 📝 Backup Checklist

### Before Major Deployment
- [ ] Create manual backup
- [ ] Document backup ID
- [ ] Verify backup completion
- [ ] Test rollback procedure
- [ ] Notify team of backup location

### After Incident
- [ ] Document what happened
- [ ] Update recovery procedures
- [ ] Test restoration process
- [ ] Review and improve

---

## 🎯 Improvement Plan

### Short Term (1 month)
- [ ] Upgrade to Supabase Pro for PITR
- [ ] Set up automated backup monitoring
- [ ] Create backup restoration scripts
- [ ] Document first successful restoration

### Medium Term (3 months)
- [ ] Implement multi-region replication
- [ ] Set up external backup storage (S3)
- [ ] Automate disaster recovery
- [ ] Reduce RTO to < 2 hours

### Long Term (6 months)
- [ ] Implement real-time replication
- [ ] Set up hot standby database
- [ ] Achieve RTO < 1 hour
- [ ] Zero data loss (RPO = 0)

---

## 📚 Additional Resources

- [Supabase Backup Documentation](https://supabase.com/docs/guides/platform/backups)
- [PostgreSQL Backup Best Practices](https://www.postgresql.org/docs/current/backup.html)
- [Disaster Recovery Planning Guide](https://www.ready.gov/business/implementation/IT)

---

**Last Tested**: [Date]  
**Next Test**: [Date]  
**Test Result**: [Pass/Fail]

---

## ✅ Quick Reference

### Restore Database
```bash
# Supabase Dashboard
Database → Backups → Select Backup → Restore

# Estimated Time: 30-60 minutes
```

### Enable Maintenance Mode
```sql
UPDATE feature_flags
SET is_enabled = true
WHERE flag_key = 'maintenance_mode';
```

### Check Backup Status
```bash
# Supabase Dashboard
Database → Backups → View History
```

---

**Remember**: Test your backups regularly. A backup you haven't tested is not a backup!
