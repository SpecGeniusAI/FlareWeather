#!/usr/bin/env python3
"""
Test script for FlareWeather Backend Deployment
Run this after deploying to verify everything works
"""

import requests
import json

def test_deployment(base_url):
    """Test the deployed FlareWeather backend"""
    
    print(f"🧪 Testing FlareWeather Backend at: {base_url}")
    
    # Test 1: Health Check
    print("\n1. Testing health endpoint...")
    try:
        response = requests.get(f"{base_url}/health")
        if response.status_code == 200:
            print("✅ Health check passed")
            print(f"   Response: {response.json()}")
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health check error: {e}")
        return False
    
    # Test 2: Root endpoint
    print("\n2. Testing root endpoint...")
    try:
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            print("✅ Root endpoint passed")
            print(f"   Response: {response.json()}")
        else:
            print(f"❌ Root endpoint failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Root endpoint error: {e}")
    
    # Test 3: Analyze endpoint
    print("\n3. Testing analyze endpoint...")
    test_data = {
        "symptoms": [
            {"timestamp": "2025-10-19T08:00:00Z", "symptom_type": "Pain", "severity": 8},
            {"timestamp": "2025-10-19T12:00:00Z", "symptom_type": "Fatigue", "severity": 6}
        ],
        "weather": [
            {"timestamp": "2025-10-19T08:00:00Z", "temperature": 18.5, "humidity": 80, "pressure": 1007, "wind": 15},
            {"timestamp": "2025-10-19T12:00:00Z", "temperature": 20.1, "humidity": 78, "pressure": 1005, "wind": 22}
        ]
    }
    
    try:
        response = requests.post(
            f"{base_url}/analyze",
            json=test_data,
            headers={"Content-Type": "application/json"}
        )
        if response.status_code == 200:
            print("✅ Analyze endpoint passed")
            result = response.json()
            print(f"   AI Message: {result.get('ai_message', 'No message')}")
            print(f"   Correlations: {result.get('strongest_factors', {})}")
        else:
            print(f"❌ Analyze endpoint failed: {response.status_code}")
            print(f"   Response: {response.text}")
    except Exception as e:
        print(f"❌ Analyze endpoint error: {e}")
    
    print(f"\n🎉 FlareWeather Backend is ready!")
    print(f"📱 Update your iOS app's baseURL to: {base_url}")
    return True

if __name__ == "__main__":
    # Replace with your actual deployment URL
    DEPLOYMENT_URL = "https://your-app-name.railway.app"
    
    print("🚀 FlareWeather Backend Deployment Test")
    print("=" * 50)
    
    # Uncomment the line below and replace with your actual URL
    # test_deployment(DEPLOYMENT_URL)
    
    print("\n📝 Instructions:")
    print("1. Deploy your backend to Railway")
    print("2. Get your deployment URL")
    print("3. Replace DEPLOYMENT_URL above with your actual URL")
    print("4. Run this script: python test_deployment.py")
    print("5. Update your iOS app with the new URL")
