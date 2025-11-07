# Quick Test in Emulator - 3 Steps

## Step 1: Start Backend (Terminal)

Open Terminal and run:
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
./start_backend.sh
```

**OR manually:**
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

**⏸️ Keep this terminal open!**

## Step 2: Run iOS App (Xcode)

1. Open Xcode
2. Press **⌘R** (or click Run button)
3. Wait for simulator to launch

## Step 3: Check Results

### In the App:
- Home screen should show AI Insights card
- You should see the AI message
- **Citations** should appear below (if papers found)

### In Xcode Console:
Look for messages like:
- `📤 Sending request to: http://localhost:8000/analyze`
- `✅ Success! Received insight with X citations`
- `📚 Citations: [...]`

### In Backend Terminal:
Look for:
- `🔍 Searching papers for: headache AND barometric pressure`
- `✅ Found X papers from EuropePMC`

## What You'll See

**If papers are found:**
- AI message with research-backed insights
- Citations section with PMCID numbers

**If no papers found:**
- AI message (generic insight)
- No citations (normal - EuropePMC may not always have results)

## Troubleshooting

**"Connection refused"**
→ Make sure backend is running (Step 1)

**No citations showing**
→ This is normal if no papers found. Check backend console.

**Backend errors**
→ Check if OpenAI API key is in `.env` file (optional for basic testing)

---

**That's it!** Start backend, run app, check results. 🚀

