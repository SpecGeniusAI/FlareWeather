#!/bin/bash
# Manual PostgreSQL backup script for Railway
# This can be used as a fallback or for custom backup needs

# Get database URL from environment
DATABASE_URL="${DATABASE_URL:-${BACKUP_DATABASE_URL}}"

if [ -z "$DATABASE_URL" ]; then
    echo "❌ Error: DATABASE_URL or BACKUP_DATABASE_URL not set"
    exit 1
fi

# Extract database name from URL
DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${DB_NAME}_${TIMESTAMP}.sql"

# Backup directory (can be Railway volume or local)
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"

echo "📦 Starting backup of database: $DB_NAME"
echo "   Timestamp: $TIMESTAMP"
echo "   Output: $BACKUP_DIR/$BACKUP_FILE"

# Perform backup using pg_dump
pg_dump "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    # Compress backup
    gzip "$BACKUP_DIR/$BACKUP_FILE"
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE.gz" | cut -f1)
    echo "✅ Backup completed successfully"
    echo "   File: $BACKUP_DIR/$BACKUP_FILE.gz"
    echo "   Size: $BACKUP_SIZE"
    
    # Optional: Upload to S3 (if AWS credentials are set)
    if [ -n "$AWS_S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ]; then
        echo "📤 Uploading to S3..."
        aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.gz" "s3://$AWS_S3_BUCKET/backups/$BACKUP_FILE.gz"
        if [ $? -eq 0 ]; then
            echo "✅ Uploaded to S3: s3://$AWS_S3_BUCKET/backups/$BACKUP_FILE.gz"
        else
            echo "⚠️  S3 upload failed"
        fi
    fi
    
    # Optional: Clean up old backups (keep last 7 days)
    if [ -n "$CLEANUP_OLD_BACKUPS" ]; then
        find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +7 -delete
        echo "🧹 Cleaned up backups older than 7 days"
    fi
else
    echo "❌ Backup failed"
    exit 1
fi
