# Testing in iOS Emulator - Step by Step

## What I've Done

✅ Updated iOS app to display citations  
✅ Changed backend URL to `http://localhost:8000` for local testing  
✅ Added citations display in HomeView  
✅ Added better error messages and logging  

## Steps to Test

### 1. Start Backend Server (Terminal)

Open Terminal and run:
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

**Keep this terminal window open!** (The server needs to keep running)

### 2. Run iOS App (Xcode)

1. Open Xcode
2. Press **⌘R** to build and run
3. Wait for app to launch in simulator

### 3. What You Should See

1. **Home Screen** loads
2. **AI Insights Card** shows:
   - Loading indicator briefly
   - Then the AI message (~150 words)
   - **Citations section** below (if papers found):
     - "Research Sources" header
     - List of PMCID/titles (e.g., "PMC1234567")

### 4. Check Console Logs

**Backend Terminal** - You should see:
```
🔍 Searching papers for: headache AND barometric pressure
✅ Found 3 papers from EuropePMC
🌤️ WeatherService: ...
```

**Xcode Console** - You should see:
```
📤 Sending request to: http://localhost:8000/analyze
📥 Response status: 200
✅ Success! Received insight with 3 citations
📚 Citations: ["PMC1234567", "PMC2345678", ...]
```

## Troubleshooting

### Backend won't start
```bash
# Install dependencies
pip install -r requirements.txt

# Then try again
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### "Connection refused" error
- Make sure backend is running (check terminal)
- Verify port 8000 is not in use: `lsof -i :8000`
- Check iOS console for exact error

### No citations showing
- Check backend console for paper search results
- Citations only show if papers are found
- If no papers found, you'll still get an insight (just no citations)

### OpenAI API errors
- Make sure you have `.env` file with `OPENAI_API_KEY`
- Backend will still work but may use fallback responses

## What to Test

1. ✅ Backend starts without errors
2. ✅ iOS app connects to localhost:8000
3. ✅ AI insights load in the app
4. ✅ Citations appear (if papers found)
5. ✅ Error messages are helpful if backend is down

---

**Ready!** Start the backend, then run the iOS app.

