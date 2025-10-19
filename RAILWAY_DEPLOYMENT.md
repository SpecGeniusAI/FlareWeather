# Railway Deployment Instructions

## Manual Deployment Steps:

### 1. Files Created ✅
- `requirements.txt` - Python dependencies
- `Procfile` - Railway process configuration
- `railway.toml` - Railway configuration (already exists)

### 2. Install Railway CLI
```bash
# Option 1: Using npm (if you have Node.js)
npm install -g @railway/cli

# Option 2: Download from GitHub
# Go to: https://github.com/railwayapp/cli/releases
# Download the Windows binary and add to PATH
```

### 3. Deploy to Railway
```bash
# Navigate to backend directory
cd flareweather-backend

# Login to Railway
railway login

# Initialize project
railway init

# Deploy
railway up
```

### 4. Set Environment Variables
In Railway dashboard:
1. Go to your project
2. Click on "Variables" tab
3. Add: `OPENAI_API_KEY` = `your_actual_openai_key_here`

### 5. Get Deployment URL
After deployment, Railway will provide a URL like:
`https://your-app-name.railway.app`

## Alternative: Use Railway Web Interface
1. Go to https://railway.app
2. Sign up/login
3. Click "New Project"
4. Connect your GitHub repository
5. Railway will auto-detect Python and deploy

## Files Ready for Deployment:
- ✅ requirements.txt
- ✅ Procfile  
- ✅ railway.toml
- ✅ main.py (your FastAPI app)
- ✅ .env (for local development)
