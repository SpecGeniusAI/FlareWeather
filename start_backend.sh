#!/bin/bash

# Quick start script for FlareWeather backend

echo "🚀 Starting FlareWeather Backend..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  No .env file found. Creating template..."
    echo "OPENAI_API_KEY=your_key_here" > .env
    echo "📝 Please edit .env and add your OpenAI API key"
    echo "   Then run this script again."
    exit 1
fi

# Install dependencies
echo "📦 Checking dependencies..."
pip install -q -r requirements.txt

# Start server
echo "🌐 Starting FastAPI server on http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

uvicorn app:app --host 0.0.0.0 --port 8000 --reload

