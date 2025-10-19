import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from models import CorrelationRequest, InsightResponse
from logic import calculate_correlations, generate_correlation_summary
from ai import generate_insight

app = FastAPI(title="FlareWeather API", version="1.0.0")

# Configure CORS based on environment
cors_origins = os.getenv("CORS_ORIGINS", "*").split(",") if os.getenv("CORS_ORIGINS") else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

@app.post("/analyze", response_model=InsightResponse)
async def analyze_data(request: CorrelationRequest):
    top_corr = calculate_correlations(request.symptoms, request.weather)
    correlation_summary = generate_correlation_summary(top_corr)
    ai_summary = generate_insight(top_corr)
    return InsightResponse(
        correlation_summary=correlation_summary,
        strongest_factors=top_corr,
        ai_message=ai_summary
    )

@app.get("/")
async def root():
    return {"message": "FlareWeather API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
