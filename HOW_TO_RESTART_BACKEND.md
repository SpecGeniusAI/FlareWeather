# How to Restart the Backend

## The backend is NOT in Xcode!

- **Xcode** = Runs your iOS app (Swift/SwiftUI)
- **Terminal** = Runs your backend (Python/FastAPI)

## Steps to Restart Backend

### Step 1: Find the Terminal Window
Look for a terminal window where you started the backend. It should have output like:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
```

### Step 2: Stop the Backend
In that terminal window:
1. Click on the terminal to focus it
2. Press **Ctrl+C** (or Cmd+C on Mac)
3. This will stop the server

### Step 3: Start the Backend Again
In the same terminal, run:
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### Step 4: Verify It's Running
You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
INFO:     Started reloader process
```

## If You Can't Find the Terminal Window

### Option 1: Open a New Terminal
1. Open **Terminal** app (Finder → Applications → Utilities → Terminal)
2. Run:
   ```bash
   cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
   uvicorn app:app --host 0.0.0.0 --port 8000 --reload
   ```

### Option 2: Check if Backend is Running
In Terminal, check if port 8000 is in use:
```bash
lsof -i :8000
```

If you see a Python process, you can kill it:
```bash
kill <PID>
```
(Replace `<PID>` with the process ID from the lsof output)

Then start it again:
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

## Quick Start Script

Or use the helper script I created:
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
./start_backend.sh
```

---

**Remember**: Keep the backend terminal window open while testing! The backend needs to keep running.

