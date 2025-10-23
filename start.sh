#!/bin/bash

# FlareWeather Backend Startup Script for Railway
echo "🚀 Starting FlareWeather Backend..."

# Navigate to backend directory
cd FlareWeather/flareweather-backend

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Start the FastAPI server
echo "🌐 Starting FastAPI server..."
uvicorn main:app --host 0.0.0.0 --port $PORT
