# Railway PostgreSQL Backup Setup Guide

## Option 1: Native Railway Backups (Recommended - Easiest)

Railway provides built-in automated backups for PostgreSQL databases. To enable:

1. **Go to Railway Dashboard**:
   - Navigate to your project: https://railway.app
   - Select your PostgreSQL service (usually named something like "Postgres" or "balanced-luck")

2. **Enable Backups**:
   - Click on the service
   - Go to the **"Backups"** tab (or look for "Backup" in settings)
   - Configure your backup schedule:
     - **Daily**: Backups every 24 hours, retained for 6 days
     - **Weekly**: Backups every 7 days, retained for 1 month  
     - **Monthly**: Backups every 30 days, retained for 3 months
   - You can enable multiple schedules

3. **Manual Backups**:
   - You can also trigger manual backups anytime from the Backups tab
   - Click "Create Backup" to take a snapshot immediately

4. **Restore from Backup**:
   - Select any backup from the list
   - Click "Restore" to restore that backup

## Option 2: External S3 Backups (For Long-term Storage)

If you want backups stored externally (AWS S3), Railway has a template:

1. **Deploy the S3 Backup Template**:
   - Go to: https://railway.com/deploy/postgres-s3-backups
   - Connect it to your Railway project

2. **Configure Environment Variables**:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
   - `AWS_S3_BUCKET`: S3 bucket name for backups
   - `AWS_S3_REGION`: AWS region (e.g., `us-east-1`)
   - `BACKUP_DATABASE_URL`: Your PostgreSQL connection string (from Railway)
   - `BACKUP_CRON_SCHEDULE`: Cron schedule (e.g., `0 2 * * *` for daily at 2 AM)

3. **Deploy**:
   - The template will automatically create and upload backups to S3

## Option 3: Manual Backup Script (For Custom Control)

If you want more control, you can create a backup service:

1. **Create a backup script** (see `backup_postgres.sh` below)
2. **Deploy as a separate Railway service** with a cron schedule
3. **Store backups** in Railway volumes or external storage

## Recommended Setup

For most use cases, **Option 1 (Native Railway Backups)** is the best choice:
- ✅ No additional setup required
- ✅ Automatic retention management
- ✅ Easy restore process
- ✅ Integrated with Railway dashboard
- ✅ Free for basic backup needs

**Recommended Schedule**:
- Enable **Daily backups** (retained for 6 days) - covers recent data
- Enable **Weekly backups** (retained for 1 month) - covers medium-term
- Optionally enable **Monthly backups** (retained for 3 months) - for long-term

This gives you:
- Daily snapshots for the past week
- Weekly snapshots for the past month
- Monthly snapshots for the past quarter

## Checking Your Current Backup Status

1. Go to your PostgreSQL service in Railway
2. Check the "Backups" tab
3. If you see "No backups configured", follow Option 1 above

## Important Notes

- **Backups are stored in Railway's infrastructure** (for native backups)
- **Backups count towards your storage quota**
- **Restore operations** may take a few minutes depending on database size
- **Test your restore process** periodically to ensure backups are working
