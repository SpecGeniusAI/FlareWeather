import os
from openai import OpenAI
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Initialize OpenAI client only if API key is available
api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key) if api_key else None

def generate_insight(correlations):
    if not client:
        return "AI insights are not available. Please configure your OpenAI API key in the .env file."
    
    prompt = f"""
    You are FlareWeather, a health and weather assistant.
    Based on these correlations: {correlations},
    write a short, empathetic insight (2–3 sentences) explaining
    how the user's symptoms relate to weather patterns.
    Keep it encouraging and clear for a wellness app tone.
    """
    completion = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "system", "content": "You are a health insights assistant."},
                  {"role": "user", "content": prompt}]
    )
    return completion.choices[0].message.content.strip()
