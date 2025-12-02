#!/usr/bin/env python3
"""
Test script for FlareWeather backend API
Tests the /analyze endpoint with sample data
"""

import requests
import json
from datetime import datetime, timedelta

# Backend URL - update this to your deployed URL or use localhost for testing
BASE_URL = "http://localhost:8000"  # Change to your Railway URL for production testing

def test_health_check():
    """Test the health check endpoint"""
    print("Testing /health endpoint...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}\n")
    return response.status_code == 200

def test_analyze_endpoint():
    """Test the /analyze endpoint with sample data"""
    print("Testing /analyze endpoint...")
    
    # Create sample data matching iOS format
    now = datetime.now()
    symptoms = [
        {
            "timestamp": (now - timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "symptom_type": "Headache",
            "severity": 8
        },
        {
            "timestamp": (now - timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "symptom_type": "Fatigue",
            "severity": 6
        },
        {
            "timestamp": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "symptom_type": "Dizziness",
            "severity": 5
        }
    ]
    
    weather = [
        {
            "timestamp": (now - timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "temperature": 18.5,
            "humidity": 80.0,
            "pressure": 1007.0,
            "wind": 15.0
        },
        {
            "timestamp": (now - timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "temperature": 20.1,
            "humidity": 78.0,
            "pressure": 1005.0,
            "wind": 22.0
        },
        {
            "timestamp": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "temperature": 22.3,
            "humidity": 75.0,
            "pressure": 1003.0,
            "wind": 18.0
        }
    ]
    
    request_data = {
        "symptoms": symptoms,
        "weather": weather,
        "user_id": None
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/analyze",
            json=request_data,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Success!")
            print(f"Correlation Summary: {result.get('correlation_summary', 'N/A')}")
            print(f"Strongest Factors: {result.get('strongest_factors', {})}")
            print(f"AI Message: {result.get('ai_message', 'N/A')[:100]}...")
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection error: Make sure the backend server is running")
        print(f"   Try: uvicorn app:app --host 0.0.0.0 --port 8000")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_edge_cases():
    """Test edge cases that might cause 400/500 errors"""
    print("\nTesting edge cases...")
    
    # Test 1: Empty symptoms
    print("\n1. Testing with empty symptoms...")
    try:
        response = requests.post(
            f"{BASE_URL}/analyze",
            json={"symptoms": [], "weather": [{"timestamp": "2025-01-01T00:00:00Z", "temperature": 20, "humidity": 50, "pressure": 1013, "wind": 10}]},
            headers={"Content-Type": "application/json"}
        )
        print(f"   Status: {response.status_code} (Expected: 400)")
        assert response.status_code == 400, "Should return 400 for empty symptoms"
    except Exception as e:
        print(f"   Error: {e}")
    
    # Test 2: Invalid timestamp format
    print("\n2. Testing with invalid timestamp...")
    try:
        response = requests.post(
            f"{BASE_URL}/analyze",
            json={
                "symptoms": [{"timestamp": "invalid-date", "symptom_type": "Headache", "severity": 5}],
                "weather": [{"timestamp": "2025-01-01T00:00:00Z", "temperature": 20, "humidity": 50, "pressure": 1013, "wind": 10}]
            },
            headers={"Content-Type": "application/json"}
        )
        print(f"   Status: {response.status_code} (Expected: 400)")
        assert response.status_code == 400, "Should return 400 for invalid timestamp"
    except Exception as e:
        print(f"   Error: {e}")
    
    # Test 3: Single data point (should handle gracefully)
    print("\n3. Testing with single data point...")
    try:
        response = requests.post(
            f"{BASE_URL}/analyze",
            json={
                "symptoms": [{"timestamp": "2025-01-01T00:00:00Z", "symptom_type": "Headache", "severity": 5}],
                "weather": [{"timestamp": "2025-01-01T00:00:00Z", "temperature": 20, "humidity": 50, "pressure": 1013, "wind": 10}]
            },
            headers={"Content-Type": "application/json"}
        )
        print(f"   Status: {response.status_code} (Should handle gracefully)")
        if response.status_code == 200:
            result = response.json()
            print(f"   Response: {result.get('correlation_summary', 'N/A')}")
    except Exception as e:
        print(f"   Error: {e}")

if __name__ == "__main__":
    print("=" * 60)
    print("FlareWeather Backend API Test")
    print("=" * 60)
    print(f"Testing against: {BASE_URL}\n")
    
    # Run tests
    health_ok = test_health_check()
    
    if health_ok:
        analyze_ok = test_analyze_endpoint()
        test_edge_cases()
        
        print("\n" + "=" * 60)
        if analyze_ok:
            print("✅ All tests passed!")
        else:
            print("❌ Some tests failed. Check the output above.")
    else:
        print("❌ Health check failed. Make sure the server is running.")

