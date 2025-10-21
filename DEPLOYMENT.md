# FlareWeather Backend Deployment Guide

## 🚀 Deployment Options

### Option 1: Railway (Recommended for beginners)

Railway offers a simple deployment process with automatic HTTPS and custom domains.

#### Prerequisites:
- Railway account (free tier available)
- Railway CLI installed: `npm install -g @railway/cli`

#### Deploy Steps:
```bash
# Navigate to backend directory
cd flareweather-backend

# Login to Railway
railway login

# Deploy
railway up

# Set environment variables
railway variables set OPENAI_API_KEY=your_actual_openai_key_here
```

#### Railway Features:
- ✅ Free tier: $5 credit monthly
- ✅ Automatic HTTPS
- ✅ Custom domains
- ✅ Environment variables management
- ✅ Automatic deployments from Git

---

### Option 2: Fly.io (More control)

Fly.io offers more configuration options and better performance.

#### Prerequisites:
- Fly.io account (free tier available)
- Fly.io CLI installed: `curl -L https://fly.io/install.sh | sh`

#### Deploy Steps:
```bash
# Navigate to backend directory
cd flareweather-backend

# Login to Fly.io
fly auth login

# Launch (first time)
fly launch

# Deploy
fly deploy

# Set environment variables
fly secrets set OPENAI_API_KEY=your_actual_openai_key_here
```

#### Fly.io Features:
- ✅ Free tier: 3 shared-cpu VMs
- ✅ Global edge deployment
- ✅ Automatic HTTPS
- ✅ Custom domains
- ✅ Better performance

---

## 🔧 Environment Variables

Set these in your hosting platform:

### Required:
- `OPENAI_API_KEY`: Your OpenAI API key for AI insights

### Optional:
- `CORS_ORIGINS`: Comma-separated list of allowed origins
- `DEBUG`: Set to `false` in production
- `PORT`: Server port (usually set by platform)

---

## 📱 iOS App Configuration

After deployment, update your iOS app's `AIInsightsService.swift`:

```swift
// Replace localhost with your deployed URL
private let baseURL = "https://your-app-name.railway.app"
// or
private let baseURL = "https://your-app-name.fly.dev"
```

---

## 🧪 Testing Deployment

Test your deployed API:

```bash
# Health check
curl https://your-app-name.railway.app/health

# Test analyze endpoint
curl -X POST https://your-app-name.railway.app/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "symptoms": [{"id": "test", "timestamp": "2024-01-01T00:00:00Z", "symptom_type": "Headache", "severity": 5, "notes": "Test"}],
    "weather": [{"timestamp": "2024-01-01T00:00:00Z", "temperature": 20.0, "humidity": 60.0, "pressure": 1013.0, "wind": 10.0}],
    "user_id": "test"
  }'
```

---

## 💡 Tips

1. **Railway**: Easier setup, good for testing
2. **Fly.io**: Better performance, more configuration options
3. **Environment Variables**: Always set your OpenAI API key
4. **CORS**: Configure allowed origins for security
5. **Monitoring**: Both platforms offer logs and monitoring

Choose Railway for simplicity or Fly.io for better performance!
