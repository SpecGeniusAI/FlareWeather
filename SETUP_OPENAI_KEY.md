# 🔑 Setting Up OpenAI API Key

## Step 1: Get Your OpenAI API Key

If you don't have one yet:
1. Go to https://platform.openai.com/api-keys
2. Sign in (or create an account)
3. Click "Create new secret key"
4. Copy the key (it starts with `sk-...`)

## Step 2: Add Key to .env File

I've created a `.env` file for you. You need to:

1. **Open the `.env` file** in the project root:
   ```
   /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001/.env
   ```

2. **Replace** `your_openai_api_key_here` with your actual key:
   ```
   OPENAI_API_KEY=sk-your-actual-key-here
   ```

3. **Save the file**

## Step 3: Restart Backend

After adding the key, restart the backend (the backend needs to reload to read the new .env file).

## Quick Edit Command

You can also edit it directly in Terminal:
```bash
cd /Users/kurtishurrie/Desktop/drive-download-20251021T153533Z-1-001
nano .env
# Or use your favorite editor:
# code .env
# open -a TextEdit .env
```

## Important Notes

- ⚠️ **Never commit the .env file to git** (it's already in .gitignore)
- 🔐 **Keep your API key secret** - don't share it
- 💰 OpenAI charges for API usage (but GPT-4o-mini is very cheap)

---

**Once you add the key, restart the backend and citations should work!**

