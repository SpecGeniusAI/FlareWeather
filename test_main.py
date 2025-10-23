from fastapi import FastAPI

app = FastAPI(title="FlareWeather API Test")

@app.get("/")
async def root():
    return {"message": "FlareWeather API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
