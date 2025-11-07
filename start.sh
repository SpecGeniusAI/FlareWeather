#!/bin/bash

# FlareWeather Backend Startup Script for Railway
echo "🚀 Starting FlareWeather Backend..."

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Check if app.py exists in root
echo "🔍 Checking for app.py in root directory..."
ls -la app.py

# Start the FastAPI server from root directory
echo "🌐 Starting FastAPI server..."
uvicorn app:app --host 0.0.0.0 --port $PORT
