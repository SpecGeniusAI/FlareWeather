# FlareWeather Backend

A FastAPI-based backend service for the FlareWeather iOS app that provides weather-symptom correlation analysis and AI-powered insights.

## Features

- **Weather-Symptom Correlation Analysis**: Calculates Pearson correlations between symptom severity and weather variables
- **AI-Powered Insights**: Generates empathetic, personalized insights using OpenAI GPT-4o-mini
- **CORS Enabled**: Ready for iOS development testing
- **RESTful API**: Clean, documented endpoints

## Setup

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure Environment**:
   ```bash
   cp env_template.txt .env
   # Edit .env and add your OpenAI API key
   ```

3. **Run the Server**:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

## API Endpoints

### POST `/analyze`
Analyzes symptom and weather data to generate correlations and AI insights.

**Request Body**:
```json
{
  "symptoms": [
    {
      "id": "symptom_1",
      "timestamp": "2024-01-15T10:30:00Z",
      "symptom_type": "Headache",
      "severity": 7,
      "notes": "Started after weather change"
    }
  ],
  "weather": [
    {
      "timestamp": "2024-01-15T10:00:00Z",
      "temperature": 22.5,
      "humidity": 65.0,
      "pressure": 1013.25,
      "wind": 15.2
    }
  ],
  "user_id": "user_123"
}
```

**Response**:
```json
{
  "correlation_summary": "Temperature shows a moderate negative correlation (r=-0.456) with symptom severity.",
  "strongest_factors": {
    "temperature": -0.456,
    "pressure": 0.234,
    "humidity": 0.123
  },
  "ai_message": "Your symptoms appear to be sensitive to temperature changes. When temperatures drop, you may experience increased symptom severity. Consider monitoring weather forecasts and taking preventive measures during temperature fluctuations."
}
```

### GET `/`
Health check endpoint.

### GET `/health`
Detailed health status.

## Data Models

- **SymptomEntry**: Individual symptom logs with severity (1-10 scale)
- **WeatherSnapshot**: Weather data at specific timestamps
- **CorrelationRequest**: Input for analysis
- **InsightResponse**: Generated insights and correlations

## Development

The backend is designed to work seamlessly with the FlareWeather iOS app. CORS is enabled for local development testing.

## Dependencies

- FastAPI: Modern web framework
- Pydantic: Data validation
- Pandas/NumPy: Statistical analysis
- OpenAI: AI insights generation
- Uvicorn: ASGI server
