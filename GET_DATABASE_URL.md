# How to Get DATABASE_URL from Railway

## Option 1: Check Environment Variables (Easiest)

1. **Go to Railway Dashboard**: https://railway.app
2. **Open your project** (`flareweather-production`)
3. **Click on your main service** (the app, not the database)
4. **Go to "Variables" tab**
5. **Look for `DATABASE_URL`** - it should be there automatically

If you see `DATABASE_URL`, copy it - you're done! ✅

## Option 2: Get from PostgreSQL Service

If `DATABASE_URL` is not in your app service variables:

1. **In your Railway project**, find the **PostgreSQL service**
   - It should be listed alongside your app service
   - Look for "PostgreSQL" or "Database"

2. **Click on the PostgreSQL service**

3. **Go to "Variables" tab**

4. **Look for connection strings**:
   - `DATABASE_URL` (PostgreSQL format)
   - Or individual variables: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`

5. **If you see individual variables**, construct the URL:
   ```
   postgresql://PGUSER:PGPASSWORD@PGHOST:PGPORT/PGDATABASE
   ```

## Option 3: Add PostgreSQL Service (If You Don't Have One)

If you don't have a PostgreSQL service:

1. **In Railway project**, click **"New"**
2. **Select "Database"** → **"PostgreSQL"**
3. **Railway will automatically:**
   - Create the database
   - Set `DATABASE_URL` environment variable in your app service
   - Connect everything

4. **Wait for it to provision** (takes ~30 seconds)

5. **Check your app service** → **"Variables" tab**
   - `DATABASE_URL` should now be there automatically!

## Option 4: Connect PostgreSQL to App Service

If PostgreSQL exists but `DATABASE_URL` isn't set:

1. **Click on your PostgreSQL service**
2. **Go to "Variables" tab**
3. **Find the connection details**
4. **Go back to your app service**
5. **Go to "Variables" tab**
6. **Click "New Variable"**
7. **Add**:
   - Name: `DATABASE_URL`
   - Value: `postgresql://user:password@host:port/database`
   - (Use the values from PostgreSQL service)

## Format of DATABASE_URL

The URL should look like:
```
postgresql://postgres:password@containers-us-west-XXX.railway.app:5432/railway
```

Or:
```
postgresql://user:pass@host.railway.app:5432/railway
```

## Quick Check

1. **Go to Railway** → Your project
2. **Check if you have 2 services:**
   - Your app service
   - PostgreSQL service (if not, add it!)

3. **If PostgreSQL exists:**
   - `DATABASE_URL` should be auto-set in your app service
   - Check app service → Variables tab

4. **If PostgreSQL doesn't exist:**
   - Add it (Option 3 above)
   - Railway will auto-set `DATABASE_URL`

## Important Notes

- ✅ Railway **automatically sets** `DATABASE_URL` when you add PostgreSQL
- ✅ You don't need to manually create it (usually)
- ✅ The variable is shared between services in the same project
- ✅ The format is: `postgresql://user:password@host:port/database`

## Troubleshooting

**Can't find DATABASE_URL?**
- Make sure PostgreSQL service exists
- Check app service Variables tab (not PostgreSQL service)
- Try adding PostgreSQL service again

**DATABASE_URL is in PostgreSQL service but not app service?**
- Railway should auto-set it, but you can manually copy it
- Go to app service → Variables → New Variable
- Copy the value from PostgreSQL service

