from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Optional
import pandas as pd
import numpy as np
import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

app = FastAPI(title="FlareWeather Local API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

class SymptomEntry(BaseModel):
    timestamp: str
    symptom_type: str
    severity: int

class WeatherSnapshot(BaseModel):
    timestamp: str
    temperature: float
    humidity: float
    pressure: float
    wind: float

class CorrelationRequest(BaseModel):
    symptoms: List[SymptomEntry]
    weather: List[WeatherSnapshot]
    user_id: Optional[str] = None

class InsightResponse(BaseModel):
    correlation_summary: str
    strongest_factors: Dict[str, float]
    ai_message: str

def calculate_correlations(symptoms, weather):
    df_s = pd.DataFrame([s.dict() for s in symptoms])
    df_w = pd.DataFrame([w.dict() for w in weather])
    df = pd.merge_asof(df_s.sort_values("timestamp"),
                       df_w.sort_values("timestamp"),
                       on="timestamp",
                       direction="nearest",
                       tolerance=pd.Timedelta("3h"))
    correlations = {}
    for col in ["temperature", "humidity", "pressure", "wind"]:
        correlations[col] = df["severity"].corr(df[col])
    top = dict(sorted(correlations.items(), key=lambda x: abs(x[1]), reverse=True)[:3])
    return top

def generate_insight(correlations):
    prompt = f"""
    You are FlareWeather, a health and weather assistant.
    Based on these correlations: {correlations},
    explain the connection between the user's symptoms and weather patterns
    in two sentences with an empathetic, health-positive tone.
    """
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}]
    )
    return completion.choices[0].message.content.strip()

@app.post("/analyze", response_model=InsightResponse)
async def analyze_data(request: CorrelationRequest):
    top_corr = calculate_correlations(request.symptoms, request.weather)
    ai_summary = generate_insight(top_corr)
    return InsightResponse(
        correlation_summary=str(top_corr),
        strongest_factors=top_corr,
        ai_message=ai_summary
    )

@app.get("/")
async def root():
    return {"message": "FlareWeather Local API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
