import argparse
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional

from ai import generate_flare_risk_assessment
from logic import get_upcoming_pressure_change


SCENARIOS = [
    {
        "name": "Stable Spring Morning",
        "location": "Portland, OR",
        "summary": "High pressure ridge, mild temps, light breeze.",
        "hourly": [
            (0, 1016.0, 15.5, 55, 6),
            (60, 1015.8, 16.0, 52, 7),
            (120, 1015.6, 16.3, 50, 8),
            (180, 1015.4, 17.0, 48, 9),
            (240, 1015.3, 17.5, 46, 10),
        ],
    },
    {
        "name": "Pacific Storm Drop",
        "location": "Seattle, WA",
        "summary": "Warm front with a sharp 6-hour pressure fall before rain.",
        "hourly": [
            (0, 1014.5, 13.0, 78, 12),
            (60, 1011.8, 12.5, 82, 14),
            (120, 1009.2, 12.0, 85, 18),
            (180, 1006.7, 11.5, 88, 22),
            (240, 1004.1, 11.0, 90, 28),
            (300, 1002.5, 10.5, 93, 32),
            (360, 1001.0, 10.0, 95, 35),
        ],
    },
    {
        "name": "High Wind Spike",
        "location": "Chicago, IL",
        "summary": "Rapid cold surge with pressure jump and gusty winds.",
        "hourly": [
            (0, 1004.8, 19.0, 72, 18),
            (60, 1007.9, 17.5, 65, 28),
            (120, 1011.4, 16.0, 60, 34),
            (180, 1014.8, 14.0, 55, 45),
            (240, 1016.1, 12.5, 50, 40),
        ],
    },
    {
        "name": "Southern Heatwave",
        "location": "Austin, TX",
        "summary": "Heat dome overhead: soaring temps and sticky humidity.",
        "hourly": [
            (0, 1008.5, 33.0, 70, 12),
            (60, 1008.2, 34.5, 72, 15),
            (120, 1007.9, 35.8, 74, 16),
            (180, 1007.6, 37.1, 75, 18),
            (240, 1007.1, 38.0, 76, 20),
        ],
    },
    {
        "name": "Arctic Front",
        "location": "Minneapolis, MN",
        "summary": "Cold front arriving with falling pressure and biting wind.",
        "hourly": [
            (0, 1012.7, -2.0, 65, 18),
            (60, 1010.4, -3.0, 68, 24),
            (120, 1007.9, -4.5, 72, 30),
            (180, 1005.3, -6.0, 76, 32),
            (240, 1003.6, -7.5, 80, 34),
        ],
    },
    {
        "name": "Rollercoaster Week",
        "location": "Denver, CO",
        "summary": "Mountain wave pattern with alternating ridges and troughs.",
        "hourly": [
            (0, 1010.0, 12.0, 55, 10),
            (120, 1005.5, 13.0, 52, 16),
            (240, 1012.0, 15.0, 50, 12),
            (360, 1006.2, 16.0, 48, 18),
            (480, 1013.8, 17.0, 45, 14),
            (600, 1004.9, 18.0, 40, 20),
        ],
    },
]

DIAGNOSIS_SETS = [
    ["fibromyalgia"],
    ["migraine"],
    ["chronic fatigue syndrome"],
    ["fibromyalgia", "migraine"],
    ["POTS", "chronic fatigue syndrome"],
    ["arthritis"],
]

SUPPORT_NOTES = {
    "fibromyalgia": "Pacing and soft layers can help cushion swings—give yourself permission to move gently.",
    "migraine": "Hydration, dim light, and steady breathing can ease the way if pressure nudges a flare.",
    "chronic fatigue syndrome": "Plan micro-rests around the shift; easing up before you have to can soften payback.",
    "pots": "Compression, salt, and slow positional changes may help your system ride through the change.",
    "arthritis": "Warmth, gentle mobility, and trusted comfort tools can settle joints as weather wobbles.",
}


def build_hourly_forecast(hourly_template: List[tuple], start: datetime) -> List[Dict[str, Any]]:
    data = []
    for offset_minutes, pressure, temp, humidity, wind in hourly_template:
        timestamp = start + timedelta(minutes=offset_minutes)
        data.append(
            {
                "timestamp": timestamp.replace(tzinfo=timezone.utc).isoformat(),
                "pressure": pressure,
                "temperature": temp,
                "humidity": humidity,
                "wind": wind,
            }
        )
    return data


def compute_pressure_trend(hourly: List[Dict[str, Any]]) -> str:
    if len(hourly) < 2:
        return "stable"
    first = hourly[0]["pressure"]
    last = hourly[min(len(hourly) - 1, 3)]['pressure'] if len(hourly) > 3 else hourly[-1]["pressure"]
    delta = last - first
    if delta <= -5:
        return "dropping quickly"
    if delta <= -2:
        return "dropping"
    if delta >= 5:
        return "rising quickly"
    if delta >= 2:
        return "rising"
    return "stable"


def describe_weather(hourly: List[Dict[str, Any]]) -> str:
    first = hourly[0]
    last = hourly[-1]
    delta_p = last["pressure"] - first["pressure"]
    delta_t = last["temperature"] - first["temperature"]
    delta_h = last["humidity"] - first["humidity"]
    return (
        f"Start pressure {first['pressure']:.1f} hPa → {last['pressure']:.1f} hPa (Δ {delta_p:+.1f}), "
        f"temp {first['temperature']:.1f}°C → {last['temperature']:.1f}°C (Δ {delta_t:+.1f}), "
        f"humidity {first['humidity']:.0f}% → {last['humidity']:.0f}% (Δ {delta_h:+.0f})."
    )


def heuristic_assessment(hourly: List[Dict[str, Any]], diagnoses: List[str], scenario_summary: str) -> Dict[str, Any]:
    first = hourly[0]
    last = hourly[-1]
    pressure_delta = last["pressure"] - first["pressure"]
    temp_peak = max(h["temperature"] for h in hourly)
    humidity_peak = max(h["humidity"] for h in hourly)

    magnitude = abs(pressure_delta)
    if magnitude >= 8 or temp_peak >= 37 or humidity_peak >= 90:
        risk = "HIGH"
    elif magnitude >= 5 or temp_peak >= 32 or humidity_peak >= 80:
        risk = "MODERATE"
    else:
        risk = "LOW"

    direction = "drop" if pressure_delta < 0 else "rise"
    forecast = {
        "LOW": "Weather looks fairly steady—stay tuned but enjoy the calmer pocket.",
        "MODERATE": "Expect some symptom nudges later today—build in cushions if you can.",
        "HIGH": "Big swings ahead—line up comfort plans and keep the evening gentle.",
    }[risk]

    why_parts = [scenario_summary]
    if magnitude >= 5:
        why_parts.append(f"Pressure change of {pressure_delta:+.1f} hPa within the window")
    if temp_peak >= 32:
        why_parts.append(f"Heat index climbing to {temp_peak:.1f}°C")
    if humidity_peak >= 80:
        why_parts.append("Humidity staying elevated")

    diagnosed_support = next((SUPPORT_NOTES[key] for key in SUPPORT_NOTES if any(key in d.lower() for d in diagnoses)), None)
    support_note = diagnosed_support or "Remember to pace yourself and stay hydrated—small adjustments can make the shift easier."

    pressure_alert = get_upcoming_pressure_change(hourly, datetime.now(timezone.utc), diagnoses)

    if pressure_alert:
        delta = abs(pressure_alert.get("pressure_delta", 0.0))
        if delta >= 10:
            alert_severity = "sharp"
        elif delta >= 5:
            alert_severity = "moderate"
        else:
            alert_severity = "low"
    else:
        if magnitude >= 10:
            alert_severity = "sharp"
        elif magnitude >= 5:
            alert_severity = "moderate"
        else:
            alert_severity = "low"

    personalization_score = 1
    if diagnoses:
        personalization_score += min(2, len(diagnoses))
    if risk != "LOW":
        personalization_score += 1
    if support_note:
        personalization_score += 1
    if len(diagnoses) > 1:
        personalization_score += 1
    personalization_score = min(5, personalization_score)

    return {
        "risk": risk,
        "forecast": forecast,
        "why": "; ".join(why_parts),
        "support_note": support_note if risk != "LOW" else None,
        "sources": [],
        "pressure_alert": pressure_alert,
        "alert_severity": alert_severity,
        "personalization_score": personalization_score,
    }


def run_scenario(
    scenario: Dict[str, Any],
    diagnoses: List[str],
    live: bool,
) -> Dict[str, Any]:
    start_time = datetime.now(timezone.utc).replace(microsecond=0)
    hourly_forecast = build_hourly_forecast(scenario["hourly"], start_time)
    current_weather = {
        "pressure": hourly_forecast[0]["pressure"],
        "temperature": hourly_forecast[0]["temperature"],
        "humidity": hourly_forecast[0]["humidity"],
        "wind": scenario["hourly"][0][4],
        "condition": "Variable",
    }
    pressure_trend = compute_pressure_trend(hourly_forecast)

    if live:
        risk, forecast, why, _, sources, support_note, alert_severity, personalization_score, personal_anecdote, confidence_flag, behavior_prompt = generate_flare_risk_assessment(
            current_weather=current_weather,
            pressure_trend=pressure_trend,
            weather_factor="pressure",
            papers=[],
            user_diagnoses=diagnoses,
            location=scenario["location"],
            hourly_forecast=hourly_forecast,
        )
        pressure_alert = get_upcoming_pressure_change(hourly_forecast, start_time, diagnoses)
        if not alert_severity:
            if pressure_alert:
                delta = abs(pressure_alert.get("pressure_delta", 0.0))
                if delta >= 10:
                    alert_severity = "sharp"
                elif delta >= 5:
                    alert_severity = "moderate"
                else:
                    alert_severity = "low"
            else:
                alert_severity = "low"
        if personalization_score is None:
            base_score = 1 + (1 if diagnoses else 0)
            if support_note:
                base_score += 1
            personalization_score = min(5, base_score)
    else:
        assessment = heuristic_assessment(hourly_forecast, diagnoses, scenario["summary"])
        risk = assessment["risk"]
        forecast = assessment["forecast"]
        why = assessment["why"]
        support_note = assessment["support_note"]
        sources = assessment["sources"]
        pressure_alert = assessment["pressure_alert"]
        alert_severity = assessment["alert_severity"]
        personalization_score = assessment["personalization_score"]

    weather_summary = describe_weather(hourly_forecast)

    return {
        "scenario": scenario,
        "diagnoses": diagnoses,
        "risk": risk,
        "forecast": forecast,
        "why": why,
        "support_note": support_note,
        "sources": sources,
        "weather_summary": weather_summary,
        "pressure_alert": pressure_alert,
        "pressure_trend": pressure_trend,
        "alert_severity": alert_severity,
        "personalization_score": personalization_score,
    }


def format_report(result: Dict[str, Any]) -> str:
    scenario = result["scenario"]
    location = scenario["location"]
    diagnoses = ", ".join(result["diagnoses"]) if result["diagnoses"] else "None"
    sources = result["sources"] if result["sources"] else ["None"]

    lines = [
        f"Scenario: {scenario['name']} ({location})",
        f"Diagnoses: {diagnoses}",
        f"Weather Summary: {scenario['summary']} {result['weather_summary']}",
        f"Pressure Trend: {result['pressure_trend']}",
        f"Alert Severity: {result.get('alert_severity', 'unknown')}",
        f"AI Risk Level: {result['risk']}",
        f"Forecast: {result['forecast']}",
        f"Explanation: {result['why']}",
        f"Personalization Score: {result.get('personalization_score', 'n/a')}",
    ]
    if result["support_note"]:
        lines.append(f"Support Note: {result['support_note']}")
    if result["pressure_alert"]:
        alert = result["pressure_alert"]
        lines.append(
            "Pressure Alert: "
            f"Δ {alert['pressure_delta']} hPa by {alert['trigger_time']} ({alert['alert_level']})"
            f" – {alert['suggested_message']}"
        )
    lines.append("Sources: " + "; ".join(sources))

    report = "\n".join(lines)
    return f"```\n{report}\n```"


def main():
    parser = argparse.ArgumentParser(description="Run FlareWeather AI insight scenarios")
    parser.add_argument("--live", action="store_true", help="Use live OpenAI completions")
    args = parser.parse_args()

    live = args.live
    print(f"Running scenarios in {'LIVE' if live else 'OFFLINE'} mode\n")

    for scenario in SCENARIOS:
        for diagnoses in DIAGNOSIS_SETS:
            result = run_scenario(scenario, diagnoses, live)
            print(format_report(result))
            print()


if __name__ == "__main__":
    main()
