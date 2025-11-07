# Start Local Backend for iOS Testing

## Quick Start

### Step 1: Install Dependencies
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
pip install -r requirements.txt
```

### Step 2: Set Up Environment Variables
Create a `.env` file in the root directory:
```bash
OPENAI_API_KEY=your_openai_api_key_here
```

### Step 3: Start the Backend Server
```bash
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Step 4: Test the Backend
Open in browser: http://localhost:8000

You should see:
```json
{"message": "FlareWeather API is running"}
```

### Step 5: Update iOS App URL (if needed)

The iOS app is already configured to use `http://localhost:8000` for local testing.

If you need to change it:
- Open `FlareWeather/AIInsightsService.swift`
- Line 42: `private let baseURL = "http://localhost:8000"`

## Testing the Full Flow

1. **Start Backend** (Terminal 1):
   ```bash
   uvicorn app:app --host 0.0.0.0 --port 8000 --reload
   ```

2. **Run iOS App** (Xcode):
   - Press ⌘R to build and run
   - The app will connect to localhost:8000

3. **Check Results**:
   - Log a symptom in the app
   - Check Home tab for AI insights
   - Citations should appear below the message (if papers found)

## Troubleshooting

### "Connection refused" error
- Make sure backend is running on port 8000
- Check: `lsof -i :8000` (should show uvicorn process)

### iOS can't reach localhost
- iOS Simulator can access `localhost` directly
- For physical device, you'd need your Mac's IP address (192.168.x.x)

### No papers found
- This is normal - EuropePMC search may not always return results
- Check console logs for: `🔍 Searching papers for...`
- Backend will fall back to basic insights

### OpenAI API errors
- Make sure `.env` file has `OPENAI_API_KEY`
- Check backend console for error messages

## What to Expect

When you run the app:
1. Backend will search EuropePMC for papers
2. If found, GPT-4o will use them in the response
3. Citations will appear in the iOS app below the AI message
4. If no papers found, you'll get a basic insight (no citations)

---

**Ready to test!** Start the backend and run the iOS app.

