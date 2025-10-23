#!/bin/bash

# FlareWeather Backend Startup Script for Railway
echo "🚀 Starting FlareWeather Backend..."

# Install dependencies from root requirements.txt
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Navigate to backend directory for the app
echo "📁 Navigating to backend directory..."
cd FlareWeather/flareweather-backend

# Check if main.py exists
echo "🔍 Checking for main.py..."
ls -la main.py

# Set Python path to current directory
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# Start the FastAPI server
echo "🌐 Starting FastAPI server..."
uvicorn main:app --host 0.0.0.0 --port $PORT
