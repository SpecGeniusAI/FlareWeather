#!/bin/bash

# FlareWeather Backend Deployment Script for Fly.io

echo "🚀 Deploying FlareWeather Backend to Fly.io..."

# Check if Fly.io CLI is installed
if ! command -v fly &> /dev/null; then
    echo "❌ Fly.io CLI not found. Installing..."
    curl -L https://fly.io/install.sh | sh
fi

# Navigate to backend directory
cd flareweather-backend

# Login to Fly.io (if not already logged in)
echo "🔐 Logging into Fly.io..."
fly auth login

# Launch the application (first time only)
echo "🚀 Launching application..."
fly launch --no-deploy

# Set environment variables
echo "🔧 Setting environment variables..."
echo "Please enter your OpenAI API key:"
read -s OPENAI_KEY

fly secrets set OPENAI_API_KEY=$OPENAI_KEY

# Deploy the application
echo "📦 Deploying to Fly.io..."
fly deploy

echo "✅ Deployment complete!"
echo "🌐 Your app is now live at: https://your-app-name.fly.dev"
echo "📱 Update your iOS app's AIInsightsService.swift with the new URL"
