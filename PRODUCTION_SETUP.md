# Production Setup Guide

## User Account Storage

### Current Setup
- **User accounts are stored on the backend server** (not locally on devices)
- Authentication uses JWT tokens (stored securely in iOS Keychain)
- User credentials are hashed with bcrypt

### Development vs Production

#### Development (Local)
- Uses **SQLite** database (`flareweather.db` file)
- Database file is created automatically when backend starts
- Data persists locally on your machine

#### Production (Railway)
- Uses **PostgreSQL** database (Railway automatically provisions this)
- Railway sets `DATABASE_URL` environment variable automatically
- User accounts are stored in the cloud database
- Data persists across deployments

### What's Stored Where

#### Backend Database (Server)
- User email
- Hashed password (bcrypt)
- User ID
- Name
- Created/updated timestamps

#### iOS Device (Local - CoreData)
- User profile preferences (name, age, diagnoses)
- Weather data cache
- Symptom entries (if tracking)
- **Note**: This is separate from authentication - it's local app data

### Setting Up Production Database

1. **Add PostgreSQL Service on Railway**:
   - Go to your Railway project
   - Click "New" → "Database" → "PostgreSQL"
   - Railway automatically sets `DATABASE_URL` environment variable

2. **The Code Auto-Detects**:
   - When `DATABASE_URL` starts with `postgresql://`, it uses PostgreSQL
   - When no `DATABASE_URL` is set, it defaults to SQLite (local)

3. **Database Tables**:
   - Tables are created automatically on first startup via `init_db()`
   - No manual migration needed for initial setup

### Important Notes

✅ **User accounts persist** - All user signups/logins are stored in the database
✅ **Secure** - Passwords are hashed, never stored in plain text
✅ **Scalable** - PostgreSQL can handle many concurrent users
✅ **Backup** - Railway provides automatic backups for PostgreSQL databases

### Migration from Development to Production

When deploying to production:
1. Add PostgreSQL service on Railway
2. Deploy your code (Railway auto-detects PostgreSQL)
3. Tables are created automatically
4. Users sign up fresh (no data migration needed)
5. Existing local SQLite data stays local (development only)

