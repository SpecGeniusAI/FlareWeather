#!/bin/bash

# FlareWeather Backend Deployment Script for Railway

echo "🚀 Deploying FlareWeather Backend to Railway..."

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Navigate to backend directory
cd flareweather-backend

# Login to Railway (if not already logged in)
echo "🔐 Logging into Railway..."
railway login

# Deploy the application
echo "📦 Deploying to Railway..."
railway up

# Set environment variables
echo "🔧 Setting environment variables..."
echo "Please enter your OpenAI API key:"
read -s OPENAI_KEY

railway variables set OPENAI_API_KEY=$OPENAI_KEY

echo "✅ Deployment complete!"
echo "🌐 Your app is now live at: https://your-app-name.railway.app"
echo "📱 Update your iOS app's AIInsightsService.swift with the new URL"
