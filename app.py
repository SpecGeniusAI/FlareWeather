from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="FlareWeather API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

@app.get("/")
async def root():
    return {"message": "FlareWeather API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.post("/analyze")
async def analyze_data(data: dict = None):
    return {
        "correlation_summary": "Mock analysis complete",
        "strongest_factors": {"temperature": 0.5, "humidity": 0.3},
        "ai_message": "Your symptoms show moderate correlation with temperature changes. Consider monitoring weather patterns and taking preventive measures during temperature fluctuations."
    }
