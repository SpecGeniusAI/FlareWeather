#!/bin/bash

# FlareWeather Backend Startup Script for Railway
echo "🚀 Starting FlareWeather Backend..."

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Check if main.py exists in root
echo "🔍 Checking for main.py in root directory..."
ls -la main.py

# Start the FastAPI server from root directory
echo "🌐 Starting FastAPI server..."
uvicorn main:app --host 0.0.0.0 --port $PORT
