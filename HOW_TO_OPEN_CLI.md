# How to Open CLI (Command Line Interface)

## On Mac

### Method 1: Terminal App (Built-in)

1. **Open Terminal:**
   - Press `Cmd + Space` (Spotlight search)
   - Type: `Terminal`
   - Press `Enter`

   OR

   - Go to **Applications** → **Utilities** → **Terminal**

2. **You'll see a window with a prompt like:**
   ```
   kurtishurrie@MacBook-Pro ~ %
   ```

3. **You're now in the CLI!**

### Method 2: VS Code/Cursor Integrated Terminal

If you're using Cursor (or VS Code):

1. **Open the integrated terminal:**
   - Press `` Ctrl + ` `` (backtick key, usually above Tab)
   - OR go to **Terminal** → **New Terminal** in the menu

2. **A terminal will open at the bottom of your editor**

---

## Install Railway CLI

Once you have Terminal open, install Railway CLI:

```bash
npm i -g @railway/cli
```

If you don't have Node.js/npm installed:
```bash
# Install Node.js first from: https://nodejs.org
# Then run the npm command above
```

---

## Login to Railway

```bash
railway login
```

This will open your browser to authenticate.

---

## Connect to Your Project

```bash
# Navigate to your project directory
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001

# Link to your Railway project
railway link
```

Select your project when prompted.

---

## Run the Query Script

```bash
railway run python query_apple_subscriptions.py
```

---

## Alternative: Use Railway Dashboard (No CLI Needed)

If you don't want to use CLI, you can run commands directly in Railway:

1. Go to https://railway.app
2. Click on your project
3. Click on your backend service
4. Go to **Settings** → **Deployments**
5. Look for **"Run Command"** or **"Shell"** option
6. Enter: `python query_apple_subscriptions.py`
7. Click **Run**

---

## Quick Test

To test if Terminal is working, type:
```bash
echo "Hello World"
```

You should see: `Hello World`

Then try:
```bash
python3 --version
```

You should see your Python version.

---

## Need Help?

- **Terminal not working?** Make sure you're in the right directory
- **Railway CLI not found?** Make sure npm is installed and Railway CLI is installed globally
- **Permission denied?** You might need to use `sudo` (but try without first)
