import os
import random
import re
from datetime import datetime, timedelta
from typing import List, Tuple, Dict, Optional
from openai import OpenAI
from dotenv import load_dotenv
from paper_search import format_papers_for_prompt
import json

# Load environment variables from .env file
load_dotenv()

# Initialize OpenAI client only if API key is available
api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key) if api_key else None

# Initialize Claude client (Anthropic) - faster alternative
try:
    from anthropic import Anthropic
    claude_api_key = os.getenv("ANTHROPIC_API_KEY") or os.getenv("CLAUDE_API_KEY")
    claude_client = Anthropic(api_key=claude_api_key) if claude_api_key else None
    if claude_client:
        print("✅ Claude (Anthropic) client initialized - will use for faster insights")
    else:
        print("ℹ️  Claude API key not found - will use OpenAI only")
except ImportError:
    print("⚠️  Anthropic SDK not installed - install with: pip install anthropic")
    claude_client = None
except Exception as e:
    print(f"⚠️  Claude client initialization error: {e}")
    claude_client = None

# Date-based comfort tip tracking to prevent repeats for 30+ days
_comfort_tip_history: Dict[str, List[str]] = {}  # Maps date strings (YYYY-MM-DD) to lists of tips used

# Simple cache for insight generation (weather pattern -> insight response)
# Cache expires after 1 hour to allow for weather changes
_insight_cache: Dict[str, Tuple[float, str, str, str, str, List[str], Optional[str], str, int, Optional[str], Optional[str]]] = {}
_CACHE_TTL_SECONDS = 3600  # 1 hour


def _get_today_date_string() -> str:
    """Get today's date as YYYY-MM-DD string."""
    return datetime.now().strftime("%Y-%m-%d")


def _get_recent_tips(days: int = 30, db_session=None) -> List[str]:
    """
    Get all comfort tips used in the last N days.
    Queries database if db_session is provided, otherwise uses in-memory cache.
    
    Args:
        days: Number of days to look back (default 30)
        db_session: Optional database session to query from DailyForecast table
        
    Returns:
        List of all tips used in the specified time period
    """
    recent_tips = []
    
    # If database session is provided, query from database (persistent across restarts)
    if db_session:
        try:
            from database import DailyForecast
            from sqlalchemy import func
            
            cutoff_date = datetime.now().date() - timedelta(days=days)
            
            # Query all unique comfort tips from the last N days
            results = db_session.query(DailyForecast.daily_comfort_tip).filter(
                DailyForecast.forecast_date >= cutoff_date,
                DailyForecast.daily_comfort_tip.isnot(None),
                DailyForecast.daily_comfort_tip != ""
            ).distinct().all()
            
            # Extract tips from query results
            recent_tips = [tip[0] for tip in results if tip[0]]
            
            # Also update in-memory cache for faster subsequent lookups
            today = datetime.now()
            for i in range(days):
                check_date = today - timedelta(days=i)
                date_str = check_date.strftime("%Y-%m-%d")
                # Query tips for this specific date
                date_results = db_session.query(DailyForecast.daily_comfort_tip).filter(
                    func.date(DailyForecast.forecast_date) == check_date.date(),
                    DailyForecast.daily_comfort_tip.isnot(None),
                    DailyForecast.daily_comfort_tip != ""
                ).distinct().all()
                if date_results:
                    if date_str not in _comfort_tip_history:
                        _comfort_tip_history[date_str] = []
                    for tip in date_results:
                        if tip[0] and tip[0] not in _comfort_tip_history[date_str]:
                            _comfort_tip_history[date_str].append(tip[0])
        except Exception as e:
            print(f"⚠️  Error querying database for recent tips: {e}")
            # Fall back to in-memory cache
    
    # Fallback to in-memory cache if no db_session or query failed
    if not recent_tips:
        today = datetime.now()
        for i in range(days):
            check_date = today - timedelta(days=i)
            date_str = check_date.strftime("%Y-%m-%d")
            if date_str in _comfort_tip_history:
                recent_tips.extend(_comfort_tip_history[date_str])
    
    return recent_tips


def _cleanup_old_tip_history(days_to_keep: int = 35):
    """
    Remove tip history entries older than specified days.
    This prevents the dictionary from growing indefinitely.
    
    Args:
        days_to_keep: Number of days of history to keep (default 35, slightly more than tracking window)
    """
    today = datetime.now()
    cutoff_date = today - timedelta(days=days_to_keep)
    cutoff_str = cutoff_date.strftime("%Y-%m-%d")
    
    # Remove entries older than cutoff
    dates_to_remove = [date_str for date_str in _comfort_tip_history.keys() if date_str < cutoff_str]
    for date_str in dates_to_remove:
        del _comfort_tip_history[date_str]


def _track_comfort_tip(tip: str):
    """
    Track a comfort tip as used today.
    
    Args:
        tip: The comfort tip text to track
    """
    today_str = _get_today_date_string()
    
    if today_str not in _comfort_tip_history:
        _comfort_tip_history[today_str] = []
    
    # Normalize tip for comparison (case-insensitive, trimmed)
    normalized_tip = tip.strip().lower()
    normalized_existing = [t.strip().lower() for t in _comfort_tip_history[today_str]]
    
    # Only add if not already in today's list (prevent duplicates on same day)
    if normalized_tip not in normalized_existing:
        _comfort_tip_history[today_str].append(tip.strip())
    
    # Clean up old entries periodically
    if len(_comfort_tip_history) > 40:  # Clean up when we have more than 40 days
        _cleanup_old_tip_history()


def _describe_temperature(value: float) -> str:
    if value <= 2:
        return "chilly air"
    if value <= 10:
        return "cool air"
    if value <= 18:
        return "mild air"
    if value <= 26:
        return "warm air"
    return "heat leaning heavy"


def _describe_humidity(value: float) -> str:
    if value >= 80:
        return "heavy humidity"
    if value >= 65:
        return "humid air"
    if value <= 35:
        return "dry air"
    return ""


def _describe_wind(value: float) -> str:
    if value >= 30:
        return "gusty winds"
    if value >= 18:
        return "steady breeze"
    return ""


def _describe_pressure_trend(trend: Optional[str]) -> str:
    if not trend:
        return ""
    if "dropping" in trend:
        return "pressure is easing"
    if "rising" in trend:
        return "pressure is building"
    return f"pressure feels {trend}"


def _combine_descriptors(*descriptors: str) -> str:
    parts = [d for d in descriptors if d]
    if not parts:
        return "steady weather"
    if len(parts) == 1:
        return parts[0]
    return ", ".join(parts[:-1]) + f", {parts[-1]}"


def _next_weekday_labels(start: datetime, count: int = 7) -> List[str]:
    labels: List[str] = []
    for i in range(1, count + 1):
        day = start + timedelta(days=i)
        labels.append(day.strftime("%a"))
    return labels


def _format_daily_message(
    summary: Optional[str],
    why_line: Optional[str],
    comfort_tip: Optional[str],
    sign_off: Optional[str]
) -> str:
    summary_text = summary.strip() if summary else "Weather feels gentle and steady today."
    why_text = why_line.strip() if why_line else "Soft shifts may keep bodies feeling steadier."
    comfort_text = comfort_tip.strip() if comfort_tip else ""
    sign_off_text = sign_off.strip() if sign_off else "Move at a pace that feels kind to you."
    
    lines: List[str] = ["☀️ Daily Insight", "", summary_text, "", f"Why: {why_text}"]
    
    if comfort_text:
        lines.extend(["", f"Comfort tip: {comfort_text}"])
    
    lines.extend(["", sign_off_text])
    return "\n".join(lines).strip()


ALLOWED_COMFORT_TIPS = [
    # Chinese medicine (TCM) tips - PRIORITIZED for education (expanded for variety - 50+ tips)
    "Chinese medicine suggests a 5-minute tai-chi routine to ease muscle tension.",
    "Chinese medicine recommends acupressure on the LI4 point for headache relief.",
    "Chinese medicine suggests warm ginger tea to support circulation during cold shifts.",
    "Chinese medicine recommends gentle qigong movements to ease joint stiffness.",
    "Chinese medicine suggests warming the lower back with a hot water bottle to support kidney energy.",
    "Chinese medicine recommends massaging the GB20 points at the base of the skull for tension relief.",
    "Chinese medicine suggests slow, mindful breathing exercises to calm the nervous system.",
    "Chinese medicine recommends the Baihui point (top of head) for mental clarity during weather shifts.",
    "Chinese medicine suggests foot soaks with warm water and Epsom salt to support circulation.",
    "Chinese medicine recommends gentle neck stretches to release tension in the upper body.",
    "Chinese medicine suggests applying warm compresses to the lower abdomen to support digestion.",
    "Chinese medicine recommends the Yongquan point (sole of foot) massage for grounding energy.",
    "Chinese medicine suggests massaging the Hegu point (between thumb and index finger) for overall wellness.",
    "Chinese medicine recommends the Zusanli point (below the knee) to support energy and digestion.",
    "Chinese medicine suggests the Neiguan point (inner wrist) for calming the mind during stress.",
    "Chinese medicine recommends warm moxibustion on the lower abdomen to support circulation.",
    "Chinese medicine suggests cupping therapy techniques with gentle self-massage for muscle tension.",
    "Chinese medicine recommends the Fengchi point (back of neck) for headache and tension relief.",
    "Chinese medicine suggests warm cinnamon tea to support yang energy during cold weather.",
    "Chinese medicine recommends the Sanyinjiao point (inner ankle) for hormonal balance and relaxation.",
    "Chinese medicine suggests gentle tapping along the bladder meridian to release tension.",
    "Chinese medicine recommends the Laogong point (center of palm) for calming and grounding.",
    "Chinese medicine suggests warm foot baths with ginger to support circulation and warmth.",
    "Chinese medicine recommends the Shenmen point (ear) for stress relief and mental calm.",
    "Chinese medicine suggests the Dazhui point (upper back) for immune support during weather changes.",
    "Chinese medicine recommends warm herbal compresses with mugwort to support joint mobility.",
    "Chinese medicine suggests the Taichong point (top of foot) for emotional balance and tension relief.",
    "Chinese medicine recommends gentle meridian stretching to support energy flow.",
    "Chinese medicine suggests warm rice bags on the lower back to support kidney energy.",
    "Chinese medicine recommends the Guanyuan point (lower abdomen) for overall vitality.",
    "Chinese medicine suggests the Qihai point (below navel) for supporting life force energy.",
    "Chinese medicine recommends warm sesame oil massage to support circulation and flexibility.",
    "Chinese medicine suggests the Yinlingquan point (inner knee) for supporting fluid balance.",
    "Chinese medicine recommends gentle self-acupressure on the temples for headache relief.",
    "Chinese medicine suggests warm chrysanthemum tea to support liver energy and calm.",
    "Chinese medicine recommends the Tianshu point (abdomen) for supporting digestive comfort.",
    "Chinese medicine suggests the Weizhong point (back of knee) for supporting lower back comfort.",
    "Chinese medicine recommends warm ginger foot soaks to support yang energy circulation.",
    "Chinese medicine suggests the Baihui point combined with slow breathing for mental clarity.",
    "Chinese medicine recommends gentle ear acupressure for overall body balance.",
    "Chinese medicine suggests warm herbal teas with goji berries to support vitality.",
    "Chinese medicine recommends the Chengshan point (calf) for supporting lower body comfort.",
    "Chinese medicine suggests the Lieque point (wrist) for supporting lung energy and breathing.",
    "Chinese medicine recommends warm salt compresses to support circulation and reduce stiffness.",
    "Chinese medicine suggests the Kunlun point (ankle) for supporting back and neck comfort.",
    "Chinese medicine recommends gentle tapping on the Ren meridian to support energy flow.",
    "Chinese medicine suggests warm jujube tea to support blood circulation and calm.",
    "Chinese medicine recommends the Feishu point (upper back) for supporting respiratory comfort.",
    "Chinese medicine suggests the Pishu point (mid-back) for supporting digestive wellness.",
    "Chinese medicine recommends warm moxa on the lower back to support kidney yang energy.",
    "Chinese medicine suggests the Shenshu point (lower back) for supporting kidney energy and vitality.",
    # Ayurveda tips - PRIORITIZED for education (expanded for variety - 50+ tips)
    "Ayurveda suggests warm oil massage to support joint mobility.",
    "Ayurveda recommends gentle yoga stretches to ease muscle tension.",
    "Ayurveda suggests staying warm with layers during temperature drops.",
    "Ayurveda recommends sipping warm water with ginger to support digestion and circulation.",
    "Ayurveda suggests a warm sesame oil massage to balance vata dosha during weather shifts.",
    "Ayurveda recommends gentle pranayama breathing to calm the nervous system.",
    "Ayurveda suggests abhyanga (self-massage) with warm coconut oil for joint support.",
    "Ayurveda recommends nasya (nasal oil drops) to support sinus health during pressure changes.",
    "Ayurveda suggests drinking warm herbal teas like turmeric or tulsi to support immunity.",
    "Ayurveda recommends gentle twists and forward folds in yoga to ease stiffness.",
    "Ayurveda suggests grounding practices like walking barefoot on grass when possible.",
    "Ayurveda recommends warm baths with Epsom salt to support muscle relaxation.",
    "Ayurveda suggests the Nadi Shodhana breathing technique to balance energy channels.",
    "Ayurveda recommends warm ghee on the joints to support flexibility and reduce stiffness.",
    "Ayurveda suggests the Bhramari breathing technique (bee breath) for calming the mind.",
    "Ayurveda recommends warm oil application on the soles of feet before bed for grounding.",
    "Ayurveda suggests gentle yoga nidra (yogic sleep) for deep relaxation during stress.",
    "Ayurveda recommends warm cumin, coriander, and fennel tea to support digestion.",
    "Ayurveda suggests the Kapalabhati breathing technique to energize and clear the mind.",
    "Ayurveda recommends warm mustard oil massage for supporting circulation in cold weather.",
    "Ayurveda suggests the Sheetali breathing technique (cooling breath) for calming heat.",
    "Ayurveda recommends warm castor oil packs on the abdomen to support digestive comfort.",
    "Ayurveda suggests gentle yoga poses like child's pose and cat-cow for spinal flexibility.",
    "Ayurveda recommends warm triphala tea to support digestive wellness and balance.",
    "Ayurveda suggests the Ujjayi breathing technique (ocean breath) for steadying the mind.",
    "Ayurveda recommends warm almond oil massage to support skin and joint health.",
    "Ayurveda suggests grounding yoga poses like mountain pose and tree pose for stability.",
    "Ayurveda recommends warm ashwagandha tea to support stress resilience and energy.",
    "Ayurveda suggests the Sitali pranayama (cooling breath) for balancing internal heat.",
    "Ayurveda recommends warm oil application on the crown of head for mental clarity.",
    "Ayurveda suggests gentle forward bends in yoga to calm the nervous system.",
    "Ayurveda recommends warm cardamom tea to support digestion and respiratory comfort.",
    "Ayurveda suggests the Bhastrika breathing technique (bellows breath) for energizing.",
    "Ayurveda recommends warm oil massage with brahmi oil for supporting mental calm.",
    "Ayurveda suggests gentle hip-opening yoga poses to support lower back comfort.",
    "Ayurveda recommends warm licorice tea to support adrenal health and energy balance.",
    "Ayurveda suggests the Anulom Vilom breathing technique (alternate nostril) for balance.",
    "Ayurveda recommends warm oil application on the temples for headache and tension relief.",
    "Ayurveda suggests gentle spinal twists in yoga to support flexibility and circulation.",
    "Ayurveda recommends warm ginger and honey tea to support immunity and warmth.",
    "Ayurveda suggests the Dirgha breathing technique (three-part breath) for deep relaxation.",
    "Ayurveda recommends warm oil massage with mahanarayan oil for joint and muscle support.",
    "Ayurveda suggests grounding practices like sitting in nature to balance vata dosha.",
    "Ayurveda recommends warm cinnamon and clove tea to support circulation and warmth.",
    "Ayurveda suggests gentle restorative yoga poses for supporting recovery and rest.",
    "Ayurveda recommends warm oil application on the navel area to support digestive fire.",
    "Ayurveda suggests the Surya Bhedana breathing technique (right nostril) for energizing.",
    "Ayurveda recommends warm oil massage with dashamoola oil for supporting muscle comfort.",
    "Ayurveda suggests gentle inversion poses like legs-up-the-wall for circulation support.",
    "Ayurveda recommends warm fennel tea to support digestion and reduce bloating.",
    "Ayurveda suggests the Chandra Bhedana breathing technique (left nostril) for calming.",
    "Ayurveda recommends warm oil application on the feet with gentle massage for grounding.",
    "Ayurveda suggests gentle backbends in yoga to support spinal flexibility and energy.",
    "Ayurveda recommends warm turmeric milk (golden milk) to support joint health and calm.",
    # Western medicine tips (expanded for variety - 25+ tips)
    "Western medicine suggests gentle stretching to ease muscle tension.",
    "Western medicine recommends staying warm and hydrated during weather shifts.",
    "Western medicine suggests taking short breaks throughout the day.",
    "Western medicine recommends progressive muscle relaxation to reduce tension.",
    "Western medicine suggests maintaining consistent sleep schedules to support circadian rhythms.",
    "Western medicine recommends gentle aerobic exercise to support circulation and mood.",
    "Western medicine suggests applying heat or cold therapy based on your body's response.",
    "Western medicine recommends maintaining good posture to reduce muscle strain.",
    "Western medicine suggests staying hydrated with electrolyte-rich fluids during weather changes.",
    "Western medicine recommends gentle range-of-motion exercises to maintain joint flexibility.",
    "Western medicine suggests mindfulness meditation to support stress management.",
    "Western medicine recommends maintaining a balanced diet to support overall wellness.",
    "Western medicine suggests gradual temperature adaptation to support body adjustment.",
    "Western medicine recommends adequate rest and sleep to support recovery and resilience.",
    "Western medicine suggests gentle massage or self-massage to support muscle relaxation.",
    "Western medicine recommends maintaining social connections to support mental wellness.",
    "Western medicine suggests creating a comfortable environment with appropriate temperature and humidity.",
    "Western medicine recommends regular movement breaks to prevent stiffness and tension.",
    "Western medicine suggests deep breathing exercises to support relaxation and oxygen flow.",
    "Western medicine recommends maintaining consistent daily routines to support body rhythms.",
    "Western medicine suggests gentle yoga or Pilates to support flexibility and strength.",
    "Western medicine recommends staying active within your comfort level to support circulation.",
    "Western medicine suggests using supportive pillows and ergonomic setups to reduce strain.",
    "Western medicine recommends listening to your body's signals and adjusting activities accordingly.",
    "Western medicine suggests maintaining a positive mindset to support overall well-being.",
    # Combined approaches (prefer Eastern + Western - 15+ tips)
    "Chinese medicine recommends tai-chi for muscle tension; Western medicine suggests gentle movement.",
    "For joint stiffness, Ayurveda recommends warm oil massage; Western medicine suggests stretching.",
    "Chinese medicine suggests acupressure; Western medicine recommends staying hydrated.",
    "Ayurveda recommends pranayama breathing; Western medicine suggests progressive muscle relaxation.",
    "Chinese medicine suggests qigong movements; Western medicine recommends maintaining good posture.",
    "Ayurveda recommends abhyanga massage; Western medicine suggests applying heat therapy.",
    "Chinese medicine suggests ginger tea; Western medicine recommends staying hydrated with electrolytes.",
    "Ayurveda recommends yoga stretches; Western medicine suggests gentle range-of-motion exercises.",
    "Chinese medicine suggests foot soaks; Western medicine recommends maintaining consistent sleep.",
    "Ayurveda recommends warm oil application; Western medicine suggests gentle massage techniques.",
    "Chinese medicine suggests breathing exercises; Western medicine recommends mindfulness meditation.",
    "Ayurveda recommends herbal teas; Western medicine suggests maintaining a balanced diet.",
    "Chinese medicine suggests acupressure points; Western medicine recommends gradual temperature adaptation.",
    "Ayurveda recommends grounding practices; Western medicine suggests creating comfortable environments.",
    "Chinese medicine suggests meridian work; Western medicine recommends regular movement breaks.",
    # General fallbacks (if no specific tradition fits - minimal use)
    "Take short pauses through the day when your body needs them.",
    "Move gently at your own pace and listen to your body."
]


FORECAST_VARIANTS = {
    "LOW": [
        "Seize the day — low flare risk as weather patterns have stabilized.",
        "Take advantage — conditions are steady and may support your plans today.",
        "Good window ahead — low risk means you can plan with more confidence.",
        "Stable conditions — this may be a day to tackle what matters most.",
        "Low flare risk — weather has settled into a gentler pattern for you.",
        "Green light — atmospheric conditions are calm and body-friendly today.",
        "Smooth sailing — pressure is holding steady, giving your body a break.",
        "Favorable day — the atmosphere is cooperating, so lean into it.",
        "Calm weather pattern — your body may feel more predictable today.",
        "Steady barometer — take this opportunity while conditions stay gentle.",
        "Weather is on your side today — make the most of this stable window.",
        "Low-stress atmosphere — a good day to catch up on things you've postponed.",
        "Pressure holding flat — your joints and muscles may thank you today.",
        "Quiet weather day — fewer atmospheric triggers to navigate.",
        "Stable front — conditions favor feeling more like yourself today."
    ],
    "MODERATE": [
        "Plan ahead — moderate risk with pressure shifts expected today.",
        "Stay flexible — weather changes may require adjusting your pace.",
        "Moderate flare risk — consider lighter activities and comfort measures.",
        "Weather shifts ahead — pacing yourself may help manage any discomfort.",
        "Moderate conditions — keep plans adaptable as patterns change.",
        "Mixed signals — the atmosphere is shifting, so listen to your body.",
        "Weather in transition — some wobble expected, stay prepared.",
        "Pressure fluctuating — your body may notice the atmospheric changes.",
        "Changeable day ahead — build in buffer time for how you're feeling.",
        "Moderate activity — the barometer is restless, so pace accordingly.",
        "Weather on the move — flexibility in your schedule may help today.",
        "Shifting patterns — not the worst, but worth being mindful.",
        "Some turbulence — atmospheric changes may bring mild symptoms.",
        "Middle ground — conditions aren't extreme but warrant attention.",
        "Variable pressure — your body might feel the ups and downs today."
    ],
    "HIGH": [
        "Prioritize rest — high flare risk with significant weather shifts expected.",
        "Scale back plans — high risk means focusing on essentials today.",
        "High flare risk — rapid weather changes may trigger symptoms.",
        "Take it easy — high risk conditions call for extra self-care.",
        "High risk ahead — consider rescheduling non-essential activities.",
        "Storm signals — major pressure swings may amplify symptoms today.",
        "Red flag day — the atmosphere is volatile, protect your energy.",
        "Significant shifts — your body may react strongly to today's changes.",
        "High alert — rapid barometric movement expected, go gentle on yourself.",
        "Challenging conditions — this is a day for essential tasks only.",
        "Weather upheaval — prioritize comfort and recovery measures.",
        "Intense pressure changes — scale back and give your body space.",
        "Atmospheric turmoil — symptoms may spike, so plan for rest.",
        "Major front moving through — expect your body to feel it.",
        "Demanding weather day — conserve energy and lean into support."
    ]
}

SUPPORT_NOTE_VARIANTS = {
    "fibromyalgia": [
        "Soft clothes, warm drinks, and gentle pacing can make a difference today.",
        "Give your muscles room to loosen slowly—comfort matters.",
        "Stretch gently and avoid rushing—your body deserves grace.",
        "Balance rest and warmth to stay ahead of any tightness.",
        "Even light movement might help—listen closely to how you feel.",
        "Warm layers and slow transitions can ease fibro sensitivity.",
        "Your nervous system may be extra reactive—gentle inputs help.",
        "Consider a warm bath or heating pad to preempt muscle tension.",
        "Soft textures and calm environments can reduce sensory overload.",
        "Pace your activities with rest breaks to prevent flare buildup.",
        "Light stretching before bed might help muscles settle overnight.",
        "Keep a warm drink nearby—internal warmth can soothe from within."
    ],
    "migraine": [
        "Dim light and hydration can help buffer sensory load.",
        "Find quiet where you can, and avoid pressure triggers if possible.",
        "Prep a cozy, low-sensory zone in case you need to retreat.",
        "Take breaks in calm spaces—bright screens or noise may add to load.",
        "Stay hydrated and consider limiting abrupt exposure to the elements.",
        "Blue light filters and sunglasses may help on pressure-shift days.",
        "Keep rescue remedies accessible in case symptoms escalate.",
        "Caffeine timing matters—too much or too little can trigger.",
        "Cool compresses on the neck may help when pressure climbs.",
        "Avoid skipping meals—blood sugar dips can compound sensitivity.",
        "White noise or silence can give your brain a break from processing.",
        "Gentle neck stretches may release tension before it builds."
    ],
    "chronic fatigue syndrome": [
        "Layer in gentle rest before the weather shifts demand it.",
        "Micro-rests and steady nourishment can help conserve energy.",
        "Plan for brief pauses—slow pacing can head off payback.",
        "Keep essentials within reach to spare extra effort.",
        "Prioritize restorative moments; small breaks can soften the strain.",
        "Front-load rest today to buffer against post-exertional crashes.",
        "Low-effort nutrition like smoothies can fuel without draining.",
        "Horizontal rest, even brief, can help your system recalibrate.",
        "Batch tasks and delegate where possible to protect your reserves.",
        "Accept that today's capacity may be different—adjust expectations.",
        "Gentle movement like slow walking may help without depleting.",
        "Keep stimulation low—sensory overload compounds fatigue."
    ],
    "pots": [
        "Compression, salted hydration, and unrushed transitions may support circulation.",
        "Keep fluids close and rise slowly—steady pacing helps the autonomic system.",
        "Consider electrolyte support and seated breaks to stay level.",
        "Gentle movement paired with rest can keep blood flow steadier.",
        "Cool cloths and mindful breathing can temper sudden head rushes.",
        "Avoid standing still for long periods—shift weight or sit when possible.",
        "Counter-maneuvers like crossing legs can help during upright moments.",
        "Eating smaller, more frequent meals may prevent blood pooling.",
        "Cool environments can help—heat exacerbates POTS symptoms.",
        "Keep a water bottle with electrolytes within arm's reach today.",
        "Leg exercises while seated can help pump blood back to the heart.",
        "Morning symptoms often peak—build in extra transition time."
    ],
    "arthritis": [
        "Warmth, gentle mobility, and trusted comfort tools can settle joints.",
        "Keep layers or heat packs handy if stiffness creeps in.",
        "Easing into movement may help joints stay happier as weather shifts.",
        "Slow stretches and supportive footwear can soften jolts.",
        "Give yourself permission to rest the joints that grumble first.",
        "Warm showers in the morning can help loosen overnight stiffness.",
        "Anti-inflammatory foods like turmeric or ginger may offer gentle support.",
        "Supportive braces or compression can stabilize reactive joints.",
        "Avoid repetitive motions that stress already-sensitive joints.",
        "Gentle range-of-motion exercises can keep joints from locking up.",
        "Warmth before activity and cold after can manage inflammation.",
        "Listen to which joints speak loudest and protect those first."
    ],
    "lupus": [
        "Sun protection and rest are extra important on high-risk days.",
        "Pace activities and avoid overexertion—fatigue can sneak up.",
        "Keep inflammation in check with gentle movement and hydration.",
        "Monitor for any new symptoms and rest at the first sign of flare.",
        "Stress management is key—consider breathing exercises or meditation.",
        "Indoor time may be wise if UV exposure compounds your symptoms.",
        "Anti-inflammatory nutrition can provide gentle background support.",
        "Listen to early warning signs—your body often signals before flares."
    ],
    "endometriosis": [
        "Heat on the lower abdomen can ease cramping during pressure shifts.",
        "Gentle movement may help, but rest if pain increases.",
        "Anti-inflammatory support through diet may provide background relief.",
        "Pacing and rest are key—don't push through if symptoms spike.",
        "Warm baths or heating pads can soothe pelvic tension.",
        "Loose, comfortable clothing reduces pressure on sensitive areas.",
        "Hydration and avoiding inflammatory foods may help today.",
        "Listen to your body's signals and adjust activities accordingly."
    ],
    "multiple sclerosis": [
        "Heat sensitivity may be heightened—stay cool where possible.",
        "Fatigue management is key—build in rest before you need it.",
        "Gentle stretching can help with spasticity without overexertion.",
        "Pace cognitive tasks as well as physical ones today.",
        "Cool environments and cold drinks can help manage symptoms.",
        "Balance exercises may feel harder—use support as needed.",
        "Energy envelope pacing can prevent crash cycles.",
        "Listen to both physical and cognitive fatigue signals."
    ],
    "ehlers-danlos syndrome": [
        "Joint support and compression may help stabilize hypermobile joints.",
        "Avoid end-range stretching—protect your connective tissue today.",
        "Gentle proprioceptive exercises can help with body awareness.",
        "Pace activities to prevent subluxations and dislocations.",
        "Supportive bracing may help on high-symptom days.",
        "Hydration supports connective tissue health—drink plenty of water.",
        "Rest positions that don't stress joints can prevent overnight issues.",
        "Listen to early warning signs of joint instability."
    ]
}

COMBO_SUPPORT_VARIANTS = {
    frozenset({"fibromyalgia", "migraine"}): [
        "When pressure {direction} like this, muscle tightness and sensory load can combine—soft layers, dim spaces, and hydration may smooth things out.",
        "Both fibro flare-ups and migraine sensitivity can stir here—balance gentle stretches with low-stimulus rest breaks.",
        "Expect both muscles and senses to react—pair warmth and slow movement with quiet, shaded pockets.",
        "Hydration, soft attire, and calm lighting can support both tender muscles and sensitive nerves.",
        "Layer warmth for fibro while guarding against sensory overload—slow pacing keeps both systems happier.",
        "The fibro-migraine combo can be intense on days like this—create a calm sanctuary and move gently.",
        "Both conditions share nervous system sensitivity—deep breaths and reduced stimulation can help both.",
        "Consider this a rest day if possible—both muscle and sensory symptoms may compound each other."
    ],
    frozenset({"chronic fatigue syndrome", "pots"}): [
        "Pressure {direction} can tap both energy reserves and autonomic balance—salted hydration, compression, and pre-planned rest can help.",
        "When weather swings arrive, both fatigue and circulation may wobble—schedule micro-rests and unrushed transitions.",
        "Keep electrolytes, compression, and gentle pacing in play to support both stamina and blood flow.",
        "Layer seated breaks with fluids and supportive stockings to steady both symptoms.",
        "A mix of calm pacing, hydration, and compressive support can cushion both fatigue and POTS responses.",
        "Both conditions drain energy differently—protect your reserves with extra horizontal rest today.",
        "Slow morning starts with salt loading can help both systems find their footing.",
        "Avoid prolonged standing and pace cognitive work—both CFS and POTS benefit from strategic rest."
    ],
    frozenset({"fibromyalgia", "arthritis"}): [
        "Both muscle and joint pain may flare today—warmth, gentle movement, and patience are your allies.",
        "The fibro-arthritis combination responds well to heat therapy and very slow stretching.",
        "Expect both widespread achiness and joint stiffness—layer comfort measures throughout the day.",
        "Anti-inflammatory support through warmth and gentle mobility can ease both conditions.",
        "Both systems may be reactive—prioritize comfort over productivity today.",
        "Warm baths or showers may help both muscle tension and joint stiffness simultaneously."
    ],
    frozenset({"migraine", "pots"}): [
        "Both head and circulation may feel the pressure shifts—stay hydrated and move slowly.",
        "The migraine-POTS combo benefits from dim, cool environments and steady salt/fluid intake.",
        "Sensory sensitivity and blood flow irregularities may both act up—create a calm, supportive space.",
        "Avoid sudden position changes and bright lights—both conditions appreciate gradual transitions.",
        "Extra electrolytes may help both the autonomic and migraine symptoms today."
    ],
    frozenset({"chronic fatigue syndrome", "fibromyalgia"}): [
        "Both energy depletion and muscle pain may compound—rest is genuinely productive today.",
        "The CFS-fibro overlap means pacing is doubly important—protect against post-exertional crashes.",
        "Warmth for fibro comfort combined with energy-conserving strategies for CFS can help.",
        "Both conditions share nervous system dysregulation—calming inputs benefit both.",
        "Consider this a conservation day—both systems need gentle handling during weather shifts."
    ]
}

GENERIC_SUPPORT_VARIANTS = [
    "Pacing, hydration, and kind self-talk can make any weather wobble easier.",
    "Line up comfort items and low-effort meals so you can respond softly.",
    "Gentle movement, rest breaks, and warm layers can cushion the day.",
    "Keep plans flexible and energy-friendly—you're allowed to adjust as needed.",
    "Small comforts—tea, calm music, or grounding breaths—can go a long way.",
    "Your body is doing its best to adapt—support it with patience.",
    "Prioritize the essentials and let go of what can wait.",
    "Warmth, hydration, and rest are your allies on days like this.",
    "Give yourself permission to move slower and ask for help.",
    "Focus on nourishment—your body needs fuel to handle the shifts.",
    "Create a calm environment to give your nervous system a break.",
    "Remember: bad weather days pass, and so will these symptoms.",
    "Lean into comfort rituals that have helped you before.",
    "Your capacity may be different today—and that's okay.",
    "Simple self-care can prevent symptoms from compounding."
]

STRONG_CONDITIONAL = "Many in your situation may want to preemptively scale back or buffer the day."

PERSONAL_ANECDOTES = {
    "fibromyalgia": [
        "Some users with fibromyalgia say evenings hit harder after fast pressure drops.",
        "When the pressure drops like this, many people with fibro notice extra muscle tightness.",
        "Fibro flare-ups often follow days like this—gentle pacing could help.",
        "Many fibro warriors report that weather shifts amplify their baseline pain.",
        "Users with fibromyalgia often find mornings after pressure changes particularly challenging.",
        "Widespread achiness after atmospheric shifts is a common fibro pattern.",
        "Some fibro sufferers notice increased fatigue before the pressure actually drops.",
        "Weather-sensitive fibromyalgia often responds well to preemptive warmth and rest."
    ],
    "migraine": [
        "People with migraines often report sharper sensory spikes when pressure shifts quickly.",
        "Past users with migraines said storm fronts were the most triggering.",
        "This kind of drop has historically flared migraines—hydration and quiet can go a long way.",
        "Many migraine sufferers can predict storms before the weather apps do.",
        "Barometric migraines often start with neck tension or visual disturbances.",
        "Users report that staying ahead of dehydration helps buffer pressure-triggered migraines.",
        "Some migraine sufferers find relief by treating early, before symptoms fully develop.",
        "Weather-related migraines often respond to darkness, cold compresses, and stillness."
    ],
    "arthritis": [
        "Some users with arthritis mention stiffness on cooler, low-pressure mornings.",
        "When humidity rises after a pressure drop, joint soreness is a common report.",
        "Fast-moving fronts often bring joint aches—warmth and rest might ease it.",
        "Many arthritis sufferers feel like human barometers—their joints know before they do.",
        "Morning stiffness often lingers longer on pressure-drop days.",
        "Users with arthritis frequently report that warmth before activity helps significantly.",
        "Cold, damp weather tends to be the most aggravating combination for arthritic joints.",
        "Some find that gentle movement helps more than complete rest during flares."
    ],
    "chronic fatigue syndrome": [
        "CFS users often report that weather shifts deplete their already limited reserves.",
        "Post-exertional malaise can be triggered more easily on high-pressure-change days.",
        "Many with ME/CFS find that preemptive rest before weather shifts helps prevent crashes.",
        "Brain fog often worsens during atmospheric instability for those with CFS.",
        "Users report that pacing becomes even more critical during weather transitions."
    ],
    "pots": [
        "POTS users often notice worse symptoms during low-pressure weather patterns.",
        "Heat combined with pressure drops can make POTS symptoms particularly challenging.",
        "Many with POTS report that extra salt and fluids help buffer weather-related dips.",
        "Morning symptoms may be amplified on days with significant pressure changes.",
        "Users find that compression garments become even more important during weather shifts."
    ]
}

BEHAVIOR_PROMPTS = [
    "Staying warm and moving gently can help your body adapt.",
    "Extra hydration may support your body through these shifts.",
    "Planning lighter activities may give your body more space.",
    "Taking breaks and pacing yourself can make a difference.",
    "Gentle movement and staying warm often help during changes.",
    "Listening to your body and adjusting plans as needed supports you.",
    "A slower morning routine can set a gentler tone for the day.",
    "Consider front-loading rest to buffer against later fatigue.",
    "Keeping rescue remedies accessible provides peace of mind.",
    "Gentle stretching before transitions can ease your body along.",
    "Nourishing meals and snacks help fuel your body's adaptation.",
    "Creating a cozy environment can reduce stress on your system.",
    "Brief outdoor time (if manageable) can help your body calibrate.",
    "Compression wear or supportive gear may stabilize sensitive areas.",
    "Breathing exercises can calm your nervous system during shifts."
]


def _parse_iso_timestamp(value: Optional[str]) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def _analyze_pressure_window(hourly_forecast: Optional[List[Dict[str, float]]], current_weather: Dict[str, float]) -> Tuple[str, float, str]:
    if not hourly_forecast:
        return "low", 0.0, "stable"

    points: List[Tuple[datetime, float]] = []
    for entry in hourly_forecast:
        dt = _parse_iso_timestamp(entry.get("timestamp"))
        pressure = entry.get("pressure")
        if dt is None or pressure is None:
            continue
        points.append((dt, float(pressure)))

    if not points:
        return "low", 0.0, "stable"

    points.sort(key=lambda p: p[0])
    start_time = points[0][0]
    base_pressure = current_weather.get("pressure", points[0][1])
    signed_delta = 0.0

    for dt, pressure in points:
        if dt - start_time > timedelta(hours=6):
            break
        delta = pressure - base_pressure
        if abs(delta) > abs(signed_delta):
            signed_delta = delta

    magnitude = abs(signed_delta)
    if magnitude >= 10:
        severity = "sharp"
    elif magnitude >= 5:
        severity = "moderate"
    else:
        severity = "low"

    if signed_delta < -0.1:
        direction = "drops"
    elif signed_delta > 0.1:
        direction = "rises"
    else:
        direction = "levels"

    return severity, signed_delta, direction


def _choose_forecast(risk: str, severity: str) -> str:
    variants = FORECAST_VARIANTS.get(risk.upper(), FORECAST_VARIANTS["LOW"])
    forecast = random.choice(variants)
    if severity == "sharp":
        forecast = f"{forecast} {STRONG_CONDITIONAL}"
    return forecast


def _choose_support_note(
    diagnoses: Optional[List[str]],
    severity: str,
    signed_delta: float,
    direction: str,
    risk: str
) -> Optional[str]:
    diagnoses = diagnoses or []
    normalized = [d.lower() for d in diagnoses]
    diag_set = frozenset(normalized)

    magnitude = abs(signed_delta)
    if severity == "low" and magnitude <= 2 and random.random() < 0.4:
        return None

    combo_template = COMBO_SUPPORT_VARIANTS.get(diag_set)
    if combo_template:
        base_note = random.choice(combo_template).format(direction=direction)
    else:
        collected: List[str] = []
        for diag in normalized:
            key = diag
            if key in SUPPORT_NOTE_VARIANTS:
                collected.append(random.choice(SUPPORT_NOTE_VARIANTS[key]))
        if not collected:
            collected = [random.choice(GENERIC_SUPPORT_VARIANTS)]
        elif len(collected) > 1:
            collected = collected[:2]
        base_note = " ".join(collected)

    if severity == "sharp" and STRONG_CONDITIONAL not in base_note:
        base_note = f"{base_note} {STRONG_CONDITIONAL}".strip()

    return base_note


def _personalization_score(
    diagnoses: Optional[List[str]],
    support_note: Optional[str],
    severity: str
) -> int:
    diagnoses = diagnoses or []
    normalized = [d.lower() for d in diagnoses]
    recognized = sum(1 for d in normalized if d in SUPPORT_NOTE_VARIANTS)
    if frozenset(normalized) in COMBO_SUPPORT_VARIANTS:
        recognized = max(recognized, 2)

    score = 1
    if normalized:
        score += min(2, max(1, len(normalized)))
    if support_note:
        score += 1
    if severity != "low":
        score += 1
    if recognized > 1:
        score += 1
    return min(5, score)


def _filter_app_messages(text: Optional[str]) -> Optional[str]:
    """
    Remove any app-specific messages about logging, updating, or using Flare.
    """
    if not text:
        return text
    
    # Phrases to filter out (in order of specificity - most specific first)
    filter_phrases = [
        "take one minute later to jot how you feel in Flare",
        "take one minute to jot how you feel",
        "jot how you feel in Flare",
        "teach the app what matters most",
        "what matters most to you",
        "those notes teach",
        "teach the app",
        "drop a quick update in Flare",
        "quick update in Flare",
        "update in Flare",
        "drop a quick update",
        "so the guidance stays personal to you",
        "so the guidance stays personal",
        "if anything new pops up",
        "if you notice anything new",
        "if anything new comes up",
        "log how you feel in Flare",
        "log your symptoms",
        "logging symptoms",
        "log how you feel",
        "update Flare",
        "jot how you feel",
        "jot down",
        "take notes",
        "make a note",
        "guidance stays personal",
        "one minute later",
        "one minute to"
    ]
    
    # First, normalize the text (replace em-dashes, line breaks, multiple spaces with single space)
    # This makes it easier to match phrases that might have different formatting
    # Note: Need to escape dashes or put them at the end of character class to avoid range interpretation
    normalized_text = re.sub(r'[\n\r]+', ' ', text)  # Replace line breaks with space first
    normalized_text = re.sub(r'[—–-]+', ' ', normalized_text)  # Replace em-dashes and hyphens with space
    normalized_text = re.sub(r'\s+', ' ', normalized_text)  # Replace multiple spaces with single space
    normalized_text_lower = normalized_text.lower()
    
    # Check if the normalized text contains any filter phrases
    # Also check for strong indicator combinations that suggest app usage instructions
    text_contains_filter = False
    matched_phrases = []
    
    # Check for exact filter phrases
    for phrase in filter_phrases:
        phrase_normalized = re.sub(r'\s+', ' ', phrase.lower())
        if phrase_normalized in normalized_text_lower:
            text_contains_filter = True
            matched_phrases.append(phrase)
    
    # Also check for strong indicator combinations (very aggressive check)
    # If text contains all these keywords together, it's almost certainly an app usage instruction
    strong_indicators = ["jot", "flare", "teach", "app", "matters most"]
    if all(indicator in normalized_text_lower for indicator in strong_indicators):
        text_contains_filter = True
        matched_phrases.append("strong_indicator_combination")
    
    # Check for "one minute" + "jot" + "Flare" combination
    if "one minute" in normalized_text_lower and "jot" in normalized_text_lower and "flare" in normalized_text_lower:
        text_contains_filter = True
        matched_phrases.append("one_minute_jot_flare")
    
    # Check for "those notes teach" + "app" combination
    if "those notes teach" in normalized_text_lower and "app" in normalized_text_lower:
        text_contains_filter = True
        matched_phrases.append("notes_teach_app")
    
    # If we found filter phrases, remove sentences containing them
    filtered_text = text
    if text_contains_filter:
        # Split original text by periods, em-dashes, line breaks
        sentences = re.split(r'[\.\n\r—–-]+\s*', text)
        filtered_sentences = []
        
        for sentence in sentences:
            sentence_clean = sentence.strip()
            if not sentence_clean:
                continue
            
            # Normalize sentence for comparison
            sentence_normalized = re.sub(r'[\n\r]+', ' ', sentence_clean)
            sentence_normalized = re.sub(r'[—–-]+', ' ', sentence_normalized)
            sentence_normalized = re.sub(r'\s+', ' ', sentence_normalized).lower()
            
            # Check if sentence contains any filter phrases
            should_filter = False
            for phrase in matched_phrases:
                phrase_normalized = re.sub(r'\s+', ' ', phrase.lower())
                if phrase_normalized in sentence_normalized:
                    should_filter = True
                    break
            
            # Also check for keyword combinations
            if not should_filter:
                has_jot_or_teach = any(kw in sentence_normalized for kw in ["jot", "teach", "notes teach", "teach the"])
                has_app_reference = any(kw in sentence_normalized for kw in ["flare", "app", "the app"])
                has_matters_most = "matters most" in sentence_normalized
                has_one_minute = "one minute" in sentence_normalized
                
                if (has_jot_or_teach and has_app_reference) or (has_matters_most and has_app_reference) or (has_one_minute and has_app_reference and (has_jot_or_teach or "log" in sentence_normalized)):
                    should_filter = True
            
            if not should_filter:
                filtered_sentences.append(sentence_clean)
        
        # Rejoin sentences
        if filtered_sentences:
            filtered_text = '. '.join(filtered_sentences)
        else:
            filtered_text = ""
    else:
        # Even if we didn't find exact filter phrases, do a second pass to catch keyword combinations
        # This catches cases where the AI might phrase things differently
        sentences = re.split(r'[\.\n\r—–-]+\s*', text)
        filtered_sentences = []
        
        for sentence in sentences:
            sentence_clean = sentence.strip()
            if not sentence_clean:
                continue
            
            # Normalize sentence for comparison
            sentence_normalized = re.sub(r'[\n\r]+', ' ', sentence_clean)
            sentence_normalized = re.sub(r'[—–-]+', ' ', sentence_normalized)
            sentence_normalized = re.sub(r'\s+', ' ', sentence_normalized).lower()
            
            # Check for keyword combinations that indicate app usage instructions
            has_jot_or_teach = any(kw in sentence_normalized for kw in ["jot", "teach", "notes teach", "teach the", "those notes"])
            has_app_reference = any(kw in sentence_normalized for kw in ["flare", "app", "the app"])
            has_matters_most = "matters most" in sentence_normalized
            has_one_minute = "one minute" in sentence_normalized or "one minute later" in sentence_normalized
            has_log = "log" in sentence_normalized or "logging" in sentence_normalized
            
            # Filter if sentence contains app usage instructions
            # More aggressive: if sentence mentions "jot" or "teach" AND any app reference, filter it
            # Also filter if it mentions "one minute" with app/logging references
            # Also filter if it mentions "matters most" with app reference
            should_filter = (has_jot_or_teach and has_app_reference) or \
                           (has_matters_most and has_app_reference) or \
                           (has_one_minute and has_app_reference) or \
                           (has_one_minute and (has_jot_or_teach or has_log)) or \
                           (has_log and has_app_reference) or \
                           ("one minute" in sentence_normalized and "flare" in sentence_normalized and ("jot" in sentence_normalized or "log" in sentence_normalized))
            
            if not should_filter:
                filtered_sentences.append(sentence_clean)
        
        if filtered_sentences:
            filtered_text = '. '.join(filtered_sentences)
        else:
            filtered_text = ""
    
    # Final cleanup: remove any remaining filter phrases that might have been missed
    for phrase in filter_phrases:
        # Normalize phrase and create pattern
        phrase_normalized = re.sub(r'\s+', ' ', phrase.lower())
        # Create flexible pattern that matches phrase even with different spacing
        pattern = re.compile(re.escape(phrase_normalized).replace(r'\ ', r'[\s—–-]+'), re.IGNORECASE)
        filtered_text = pattern.sub('', filtered_text)
    
    # Clean up any double spaces, double periods, or trailing/leading issues
    filtered_text = re.sub(r'\.\s*\.', '.', filtered_text)  # Remove double periods
    filtered_text = re.sub(r'\s+', ' ', filtered_text)  # Remove multiple spaces
    filtered_text = filtered_text.strip()
    
    # Remove trailing periods if they're alone
    filtered_text = filtered_text.rstrip('. ')
    
    return filtered_text if filtered_text else None


def _choose_sign_off(diagnoses: Optional[List[str]], location: Optional[str]) -> str:
    """Return a compassionate sign-off tailored to the user context."""
    base_sign_offs = [
        "Keep breathing steady and give yourself the gentlest option available.",
        "You deserve ease—take the day at the rhythm that feels kindest.",
        "Listen to your body and let supportive rest be part of the plan.",
        "Small comforts count—let them be your anchor today.",
        "You're allowed to go softly; the forecast can still be navigated with care."
    ]

    diagnosis_sign_offs = {
        "fibromyalgia": [
            "Sending warm, slow stretches your way—take the day in soft-focus.",
            "May your muscles find ease; pacing gently is more than enough.",
            "Let warmth and kindness wrap your joints—move only when it feels welcome."
        ],
        "migraine": [
            "Wishing you quiet light and hydrated pauses whenever you need them.",
            "Keep the calm close by—dim spaces and steady sips can be your allies.",
            "May today offer softened edges and gentle spaces to retreat when needed."
        ],
        "arthritis": [
            "Keep joints cozy and supported—your comfort leads the plan today.",
            "May warmth and slow motion guide you toward steadier steps.",
            "Wrap sore spots in kindness—your pace sets the tone for the day."
        ],
        "pots": [
            "Hold onto steady breaths, salted sips, and your reliable pacing.",
            "Root for calm circulation—legs up, heart steady, you're doing enough.",
            "May gentle transitions and hydration keep your day feeling grounded."
        ],
        "chronic fatigue syndrome": [
            "Energy is precious—spend it like treasure and celebrate the stillness.",
            "May each pause refill you; soft wins count just as much.",
            "Keep kindness for yourself front and center; recovery moments are productive too."
        ]
    }

    normalized = [d.lower() for d in (diagnoses or [])]
    candidate_sign_offs: List[str] = []

    for diag in normalized:
        if diag in diagnosis_sign_offs:
            candidate_sign_offs.extend(diagnosis_sign_offs[diag])

    if location:
        location_templates = [
            f"Sending steady skies over {location}—choose the calm pockets whenever they appear.",
            f"{location} can wait while you recharge—move only as the good moments allow.",
            f"Wishing you weather-kind pauses in {location}; let the gentlest plan lead the way."
        ]
        candidate_sign_offs.extend(location_templates)

    if not candidate_sign_offs:
        candidate_sign_offs = base_sign_offs

    return random.choice(candidate_sign_offs)


def generate_insight(correlations, rag_context: List[Tuple[str, str]] = None):
    """
    Generate AI insight with optional RAG context.
    
    Args:
        correlations: Dictionary of weather variable correlations
        rag_context: List of (chunk_text, source_filename) tuples from RAG
        
    Returns:
        Tuple of (ai_message, citations_list)
    """
    if not client:
        return ("AI insights are not available. Please configure your OpenAI API key in the .env file.", [])
    
    # Build base prompt
    base_prompt = f"""
You are FlareWeather, a health and weather assistant.
Based on these correlations: {correlations},
write a short, empathetic insight (~150 words) explaining
how the user's symptoms relate to weather patterns.
Keep it encouraging and clear for a wellness app tone.
"""
    
    # If RAG context is available, enhance the prompt
    if rag_context and len(rag_context) > 0:
        # Extract relevant context
        context_text = "\n\n".join([
            f"[Source: {source}]\n{chunk}"
            for chunk, source in rag_context
        ])
        
        # Build RAG-enhanced prompt
        prompt = f"""
You are FlareWeather, a health and weather assistant.

Based on these correlations: {correlations},

Use the following research context to inform your response:
{context_text}

Write a short, empathetic insight (~150 words) explaining
how the user's symptoms relate to weather patterns.
Reference the research when relevant and cite sources using [Source: filename].
Keep it encouraging and clear for a wellness app tone.
"""
        
        # Extract citations from sources
        citations = [source for _, source in rag_context]
    else:
        prompt = base_prompt
        citations = []
    
    try:
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "You are FlareWeather, a health and weather forecasting assistant. Your goal is to help users predict how they'll feel during the week based on weather patterns. Focus on forecasting, expected symptoms, and actionable advice for managing weather-related health changes."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7
        )
        ai_message = completion.choices[0].message.content.strip()
        
        # Deduplicate citations
        citations = list(set(citations))
        
        return (ai_message, citations)
    except Exception as e:
        print(f"Error generating insight: {e}")
        # Fallback to basic insight without RAG
        try:
            fallback_prompt = f"""
You are FlareWeather, a health and weather forecasting assistant.
Based on these correlations: {correlations},
write a forecasting-focused insight (~180 words) that helps users predict how they'll feel.
Focus on expected symptoms and weather patterns to watch for.
Keep it encouraging and clear for a wellness app tone.
"""
            completion = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are FlareWeather, a health and weather forecasting assistant. Help users predict how they'll feel based on weather patterns."},
                    {"role": "user", "content": fallback_prompt}
                ]
            )
            ai_message = completion.choices[0].message.content.strip()
            return (ai_message, [])
        except Exception as e2:
            print(f"Fallback also failed: {e2}")
            return ("Unable to generate insights at this time.", [])


def generate_flare_risk_assessment(
    current_weather: Dict[str, float],
    pressure_trend: Optional[str] = None,
    weather_factor: str = "pressure",
    papers: List[Dict[str, str]] = None,
    user_diagnoses: Optional[List[str]] = None,
    db_session=None,
    user_sensitivities: Optional[List[str]] = None,
    location: Optional[str] = None,
    hourly_forecast: Optional[List[Dict[str, float]]] = None
) -> Tuple[str, str, str, str, List[str], Optional[str], str, int, Optional[str], Optional[str]]:
    """Generate a daily flare insight that obeys strict formatting rules."""
    
    # Simple cache key based on weather pattern (rounded to avoid cache misses from tiny variations)
    # Only cache if no user-specific data (diagnoses/sensitivities) to keep responses personalized
    use_cache = not user_diagnoses and not user_sensitivities
    cache_key = None
    if use_cache:
        import time
        pressure = round(current_weather.get("pressure", 1013), 0)
        temp = round(current_weather.get("temperature", 20), 1)
        humidity = round(current_weather.get("humidity", 50), 0)
        cache_key = f"{pressure}_{temp}_{humidity}_{pressure_trend or 'stable'}"
        
        # Check cache
        if cache_key in _insight_cache:
            cached_time, *cached_result = _insight_cache[cache_key]
            age = time.time() - cached_time
            if age < _CACHE_TTL_SECONDS:
                print(f"⚡ Using cached insight (age: {age:.0f}s)")
                return tuple(cached_result)
            else:
                # Cache expired, remove it
                del _insight_cache[cache_key]
    
    if not client:
        fallback_message = _format_daily_message(
            "Weather feels steady today.",
            "Soft shifts keep things gentler on sensitive bodies.",
            ALLOWED_COMFORT_TIPS[1],
            "Move kindly through the day."
        )
        return (
            "MODERATE",
            "Plan ahead — moderate risk with weather shifts expected today.",
            "Soft shifts keep things gentler on sensitive bodies.",
            fallback_message,
            [],
            None,
            "moderate",
            2,
            None,
            None
        )

    papers = papers or []
    pressure = current_weather.get("pressure", 1013)
    humidity = current_weather.get("humidity", 50)
    temperature = current_weather.get("temperature", 20)
    wind = current_weather.get("wind", 0)

    severity_label, signed_delta, direction = _analyze_pressure_window(hourly_forecast, current_weather)
    alert_severity = severity_label

    weather_descriptor = _combine_descriptors(
        _describe_pressure_trend(pressure_trend),
        _describe_temperature(temperature),
        _describe_humidity(humidity),
        _describe_wind(wind)
    )

    if direction == "drops":
        hourly_note = "Upcoming hours lean more changeable."
    elif direction == "rises":
        hourly_note = "Upcoming hours may feel more settled."
    else:
        hourly_note = "Upcoming hours stay fairly steady."

    diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "general weather sensitivity"
    sensitivities_str = ", ".join(user_sensitivities) if user_sensitivities else None
    location_str = f"around {location}" if location else "in your area"
    
    # Build sensitivities context for prompt
    sensitivities_context = ""
    if sensitivities_str:
        sensitivities_context = f"\n- Triggers: {sensitivities_str}"

    # Calculate risk based on weather conditions BEFORE prompting AI
    # Force Moderate/High for extreme conditions
    calculated_risk = "LOW"
    if humidity >= 80:  # Very high humidity
        calculated_risk = "MODERATE"
    if humidity >= 90:  # Extremely high humidity
        calculated_risk = "HIGH"
    if pressure < 1000:  # Very low pressure
        calculated_risk = "HIGH" if calculated_risk == "LOW" else calculated_risk
    if pressure < 1005:  # Low pressure
        calculated_risk = "MODERATE" if calculated_risk == "LOW" else calculated_risk
    if pressure_trend and "drop" in pressure_trend.lower():
        calculated_risk = "HIGH" if calculated_risk != "HIGH" else calculated_risk
        calculated_risk = "MODERATE" if calculated_risk == "LOW" else calculated_risk
    
    # Optimized prompt - balanced for speed and quality
    prompt = f"""FlareWeather Assistant. Weather: {weather_descriptor}. Hourly: {hourly_note}. User: {diagnoses_str}{sensitivities_context}

CRITICAL RISK GUIDANCE: Based on weather conditions, the calculated risk is {calculated_risk}. You MUST use this risk level or higher. DO NOT use LOW risk if conditions warrant MODERATE or HIGH.

FORBIDDEN LANGUAGE: Never use "mild" in the summary_sentence. For high humidity (80%+), use stronger language like "heavy humidity", "damp conditions", "moisture-laden air". For extreme humidity (90%+), use "very heavy humidity", "saturated air", "intense moisture". Avoid weak descriptors.

Generate JSON:
{{
  "risk": "{calculated_risk} | MODERATE | HIGH",
  "forecast": "Actionable headline. No numbers. No 'mild' language.",
  "why": "Brief why bodies may notice.",
  "daily_insight": {{
    "summary_sentence": "[Weather] which could [impact]. NO 'mild' language - use stronger descriptors for high humidity/pressure changes.",
    "why_line": "Explain mechanism briefly.",
    "comfort_tip": "Up to 20 words. Eastern medicine. Include source like 'Chinese medicine recommends...'",
    "sign_off": "One calm sentence."
  }}
}}

Style: Grade 12 vocab. Tentative language (may, might). Short sentences. NO 'mild' descriptors."""

    risk = "MODERATE"
    forecast_from_model: Optional[str] = None
    why_from_model: Optional[str] = None
    sources: List[str] = []
    daily_summary: Optional[str] = None
    daily_why_line: Optional[str] = None
    daily_comfort_tip: str = ""
    daily_sign_off: Optional[str] = None

    # Try Claude Haiku first (2-4x faster), fall back to OpenAI if unavailable
    response_json = None
    ai_provider_used = None
    
    try:
        # Try Claude Haiku first (faster)
        if claude_client:
            try:
                print("🚀 Attempting Claude Haiku (faster)...")
                # Claude doesn't have native JSON mode, so we add JSON formatting instructions to the prompt
                json_prompt = prompt + "\n\nIMPORTANT: Respond ONLY with valid JSON matching the structure above. No markdown, no extra text."
                
                message = claude_client.messages.create(
                    model="claude-3-5-haiku-20241022",  # Fastest Claude model
                    max_tokens=280,  # Balanced for speed and completeness
                    temperature=0.3,  # Slightly higher for better quality while still fast
                    system="You translate weather moods into calm, compassionate guidance for weather-sensitive people. Always respond with valid JSON only.",
                    messages=[{"role": "user", "content": json_prompt}]
                )
                response_text = message.content[0].text.strip()
                
                # Try to extract JSON if Claude added markdown formatting
                if "```json" in response_text:
                    response_text = response_text.split("```json")[1].split("```")[0].strip()
                elif "```" in response_text:
                    response_text = response_text.split("```")[1].split("```")[0].strip()
                
                response_json = json.loads(response_text)
                ai_provider_used = "claude"
                print(f"✅ Claude Haiku response received in ~2-4s")
            except json.JSONDecodeError as e:
                print(f"⚠️  Claude response not valid JSON, trying OpenAI: {e}")
                response_json = None
            except Exception as e:
                print(f"⚠️  Claude API error, falling back to OpenAI: {e}")
                response_json = None
        
        # Fall back to OpenAI if Claude failed or unavailable
        if response_json is None and client:
            try:
                print("🔄 Using OpenAI gpt-4o-mini (fallback)...")
                completion = client.chat.completions.create(
                    model="gpt-4o-mini",  # Faster model - 2-3x speed improvement
                    messages=[
                        {"role": "system", "content": "You translate weather moods into calm, compassionate guidance for weather-sensitive people."},
                        {"role": "user", "content": prompt}
                    ],
                    temperature=0.3,  # Balanced for speed and quality
                    max_tokens=280,  # Balanced for speed and completeness
                    response_format={"type": "json_object"}
                )
                response_text = completion.choices[0].message.content.strip()
                response_json = json.loads(response_text)
                ai_provider_used = "openai"
                print(f"✅ OpenAI response received")
            except Exception as e:
                print(f"❌ OpenAI also failed: {e}")
                raise
        
        if response_json is None:
            raise Exception("No AI provider available (Claude and OpenAI both failed)")

        # Parse response (same format for both Claude and OpenAI)
        risk = response_json.get("risk", calculated_risk).upper()
        # Ensure risk is at least as high as calculated risk
        risk_levels = {"LOW": 1, "MODERATE": 2, "HIGH": 3}
        if risk_levels.get(risk, 1) < risk_levels.get(calculated_risk, 1):
            risk = calculated_risk
            print(f"⚠️ AI returned {response_json.get('risk')} but conditions warrant {calculated_risk} - forcing {calculated_risk}")
        
        forecast_from_model = response_json.get("forecast")
        why_from_model = response_json.get("why")
        sources = response_json.get("sources", []) or []

        daily_json = response_json.get("daily_insight", {}) or {}
        daily_summary = daily_json.get("summary_sentence")
        daily_why_line = daily_json.get("why_line")
        daily_comfort_tip = daily_json.get("comfort_tip") or ""
        daily_sign_off = daily_json.get("sign_off")
        
        # VALIDATION: Reject "mild" language in daily_summary, especially for high humidity
        if daily_summary and "mild" in daily_summary.lower():
            if humidity >= 80:
                print(f"⚠️ Rejecting 'mild' language in daily summary for high humidity ({humidity}%) - replacing")
                # Replace with stronger language
                if humidity >= 90:
                    daily_summary = f"Heavy humidity and {_describe_temperature(temperature)} which could create noticeable physiological tension."
                else:
                    daily_summary = f"High humidity and {_describe_temperature(temperature)} which could create some physiological tension."
            else:
                # Even for lower humidity, avoid "mild" - use neutral language
                daily_summary = daily_summary.replace("mild", "").replace("Mild", "").strip()
                if daily_summary.startswith("air"):
                    daily_summary = f"{_describe_temperature(temperature)} and {_describe_humidity(humidity)} which could create some physiological tension."

        # Validate comfort tip: allow generated tips with medical tradition sources (up to 20 words)
        if daily_comfort_tip:
            normalized_tip = daily_comfort_tip.strip()
            word_count = len(normalized_tip.split())
            # Allow tips up to 20 words, and check if it mentions a medical tradition source
            has_medical_source = any(source in normalized_tip.lower() for source in [
                "western medicine", "chinese medicine", "tcm", "ayurveda", 
                "traditional chinese", "traditional medicine", "suggests", "recommends"
            ])
            # Allow if it has a medical source and is within word limit, OR if it's in the allowed list
            allowed_normalized = [tip.lower() for tip in ALLOWED_COMFORT_TIPS]
            if word_count > 20 or (normalized_tip.lower() not in allowed_normalized and not has_medical_source):
                # Too long or doesn't have medical source and not in allowed list
                daily_comfort_tip = ""
            else:
                # Track AI-generated tips to prevent duplicates - check last 30 days
                # Normalize for comparison (case-insensitive)
                tip_lower = normalized_tip.lower()
                # Get all tips used in the last 30 days (query database if available)
                recent_tips_list = _get_recent_tips(days=30, db_session=db_session)
                
                # Check for similarity: exact match OR same key phrases (to catch variations)
                def tips_are_similar(tip1: str, tip2: str) -> bool:
                    """Check if two tips are similar (exact match or share key phrases)."""
                    tip1_lower = tip1.lower()
                    tip2_lower = tip2.lower()
                    
                    # Exact match
                    if tip1_lower == tip2_lower:
                        return True
                    
                    # Extract key phrases (acupressure points, techniques, etc.)
                    # Common patterns that indicate same tip even if wording differs:
                    key_phrases = [
                        "li4", "gb20", "baihui", "yongquan", "hegu", "zusanli", "neiguan", "fengchi",
                        "acupressure", "tai-chi", "qigong", "ginger tea", "foot soaks", "moxibustion",
                        "cupping", "warm compresses", "neck stretches", "breathing exercises"
                    ]
                    
                    # Check if both tips mention the same key phrase
                    for phrase in key_phrases:
                        if phrase in tip1_lower and phrase in tip2_lower:
                            # Same technique/point - likely the same tip
                            return True
                    
                    # Check for very high word overlap (80%+ of words match)
                    words1 = set(tip1_lower.split())
                    words2 = set(tip2_lower.split())
                    if len(words1) > 0 and len(words2) > 0:
                        overlap = len(words1.intersection(words2))
                        total_unique = len(words1.union(words2))
                        if total_unique > 0 and (overlap / total_unique) > 0.7:  # 70% word overlap
                            return True
                    
                    return False
                
                # Check if this tip (or very similar) was recently used
                if any(tips_are_similar(tip_lower, existing.lower()) for existing in recent_tips_list):
                    # This tip was recently used (within last 30 days), regenerate it
                    print(f"⚠️ Comfort tip too similar to recent tip - rejecting: {normalized_tip[:60]}...")
                    daily_comfort_tip = ""
                else:
                    # Track this tip as used today
                    _track_comfort_tip(normalized_tip)
        
        # FALLBACK: If comfort tip was rejected or not provided, always provide one
        if not daily_comfort_tip:
            print("⚠️ No comfort tip from AI or tip was rejected - providing fallback")
            # Get recent tips to avoid duplicates
            recent_tips_list = _get_recent_tips(days=30, db_session=db_session)
            recent_tips_lower = [t.lower() for t in recent_tips_list]
            
            # Find an unused tip from ALLOWED_COMFORT_TIPS
            available_tips = [tip for tip in ALLOWED_COMFORT_TIPS if tip.lower() not in recent_tips_lower]
            
            if available_tips:
                # Use an unused tip
                daily_comfort_tip = random.choice(available_tips)
                _track_comfort_tip(daily_comfort_tip)
                print(f"✅ Selected fallback comfort tip: {daily_comfort_tip[:50]}...")
            else:
                # All tips used recently, use a random one anyway (better than nothing)
                daily_comfort_tip = random.choice(ALLOWED_COMFORT_TIPS)
                print(f"✅ All tips used recently, using random tip: {daily_comfort_tip[:50]}...")
    except Exception as exc:  # noqa: BLE001
        print(f"❌ Error generating daily insight JSON: {exc}")
        import traceback
        traceback.print_exc()
        if pressure_trend and "drop" in (pressure_trend or "").lower():
            risk = "HIGH"
            forecast_from_model = "Prioritize rest — high flare risk with significant weather shifts expected."
            why_from_model = "Quick shifts may leave sensitive bodies feeling more reactive."
        elif pressure < 1005:
            risk = "MODERATE"
            forecast_from_model = "Plan ahead — moderate risk with pressure shifts expected today."
            why_from_model = "Soft swings may feel a little less steady."
        else:
            risk = "LOW"
            forecast_from_model = "Seize the day — low flare risk as weather patterns have stabilized."
            why_from_model = "Steadier cues often feel gentler on sensitive bodies."
        daily_summary = None
        daily_why_line = None
        daily_comfort_tip = ""
        daily_sign_off = None
        sources = []
        
        # FALLBACK: Always provide a comfort tip even on error
        if not daily_comfort_tip:
            recent_tips_list = _get_recent_tips(days=30, db_session=db_session)
            recent_tips_lower = [t.lower() for t in recent_tips_list]
            available_tips = [tip for tip in ALLOWED_COMFORT_TIPS if tip.lower() not in recent_tips_lower]
            daily_comfort_tip = random.choice(available_tips) if available_tips else random.choice(ALLOWED_COMFORT_TIPS)

    if not daily_summary:
        # Generate summary based on calculated risk and conditions
        if humidity >= 90:
            daily_summary = f"Very heavy humidity and {_describe_temperature(temperature)} which could create significant physiological tension."
        elif humidity >= 80:
            daily_summary = f"Heavy humidity and {_describe_temperature(temperature)} which could create noticeable physiological tension."
        elif calculated_risk == "HIGH":
            summary_variants_high = [
                "Fast swings keep the day feeling more reactive.",
                "The atmosphere is restless—your body may feel the turbulence.",
                "Significant pressure shifts are moving through.",
                "Weather patterns are volatile—expect your body to notice.",
                "A challenging atmospheric day lies ahead.",
                "The barometer is on a rollercoaster today.",
                "Major weather transitions are underway.",
                "Stormy patterns may amplify symptoms today."
            ]
            daily_summary = random.choice(summary_variants_high)
        elif calculated_risk == "MODERATE":
            if humidity >= 75:
                daily_summary = f"High humidity and {_describe_temperature(temperature)} which could create some physiological tension."
            else:
                summary_variants_moderate = [
                    "Weather wobbles softly through the day.",
                    "Some atmospheric fluctuation expected.",
                    "The weather is in transition mode.",
                    "Moderate changes are moving through.",
                    "Expect some ups and downs atmospherically.",
                    "The barometer is gently shifting.",
                    "Weather patterns are finding a new equilibrium.",
                    "Conditions are changeable but manageable."
                ]
                daily_summary = random.choice(summary_variants_moderate)
        else:  # LOW risk
            summary_variants_low = [
                "Weather settles into a gentler groove.",
                "A calm atmospheric day ahead.",
                "The barometer is holding steady—take advantage.",
                "Stable conditions give your body a break.",
                "Weather patterns are cooperating today.",
                "A rare window of atmospheric calm.",
                "Conditions are favorable for feeling more like yourself.",
                "The weather is on your side today."
            ]
            daily_summary = random.choice(summary_variants_low)

    if not daily_why_line:
        why_variants_sharp = [
            "Rapid pressure changes cause joint tissues to expand and contract quickly, which can press against nerve endings and create stiffness or tension.",
            "When barometric pressure drops fast, tissues swell slightly and nerves become more sensitive, amplifying pain signals.",
            "Sharp atmospheric shifts trigger inflammatory responses in the body, making chronic conditions more reactive.",
            "Fast-moving weather fronts destabilize the body's internal pressure equilibrium, often felt as increased joint or muscle discomfort.",
            "Dramatic pressure swings affect blood flow and nerve sensitivity, which can intensify existing symptoms.",
            "The body struggles to adapt when pressure changes rapidly, leading to heightened inflammation and pain perception.",
            "Significant atmospheric turbulence activates the nervous system's stress response, which can amplify chronic symptoms.",
            "When pressure plummets quickly, fluid shifts in tissues can compress nerves and increase stiffness.",
            "Rapid weather changes don't give the body time to recalibrate, leaving pain pathways more active.",
            "Storm systems create pressure gradients that the body senses through baroreceptors, often triggering symptom flares."
        ]
        why_variants_moderate = [
            "Weather shifts can cause subtle changes in body fluid retention and circulation, which may make joints or muscles feel less stable.",
            "Moderate pressure fluctuations affect how tissues hold fluid, creating a sense of heaviness or instability.",
            "The body's baroreceptors notice atmospheric changes and can trigger low-level inflammatory responses.",
            "Shifting weather patterns affect blood vessel dilation and tissue hydration, contributing to discomfort.",
            "When pressure is unstable, the nervous system stays slightly on alert, which can lower pain thresholds.",
            "Moderate atmospheric changes affect oxygen delivery to tissues, which some bodies feel as fatigue or achiness.",
            "Weather transitions cause the body to continuously readjust, which requires extra energy and may feel draining.",
            "Fluctuating conditions can disrupt sleep quality, which compounds next-day symptom sensitivity.",
            "The body expends energy adapting to changing pressure, leaving less reserve for managing chronic symptoms.",
            "Unsettled atmospheric conditions affect serotonin and other neurotransmitters that influence pain perception."
        ]
        why_variants_low = [
            "Stable weather patterns allow the body's systems to maintain consistent fluid balance and circulation, which often feels more comfortable.",
            "When pressure holds steady, the body isn't expending energy on constant adaptation, leaving more reserve for healing.",
            "Calm atmospheric conditions let the nervous system rest in a more parasympathetic state, reducing symptom sensitivity.",
            "Stable barometric pressure means tissues maintain consistent volume, reducing pressure on nerves and joints.",
            "Gentle weather patterns support better sleep quality, which helps the body recover and manage symptoms.",
            "When the atmosphere is calm, blood flow and oxygen delivery stay predictable, supporting overall comfort.",
            "Steady conditions allow inflammation levels to settle, often providing a window of reduced symptoms.",
            "The body thrives on predictability—stable weather gives your systems a chance to find equilibrium.",
            "Low atmospheric variability means fewer triggers for the body's stress and inflammatory responses.",
            "Calm weather days often correlate with improved mood and energy, which can buffer against symptom perception."
        ]
        
        if severity_label == "sharp":
            daily_why_line = random.choice(why_variants_sharp)
        elif severity_label == "moderate":
            daily_why_line = random.choice(why_variants_moderate)
        else:
            daily_why_line = random.choice(why_variants_low)

    if not daily_comfort_tip:
        # Always generate a comfort tip - PRIORITIZE Eastern medicine (Chinese medicine, Ayurveda)
        # Exclude tips used in the last 30 days to prevent repeats
        
        # Get all tips used in the last 30 days (query database if available)
        recent_tips = _get_recent_tips(days=30, db_session=db_session)
        
        # Get Eastern medicine tips, excluding recently used ones (last 30 days)
        eastern_tips = [tip for tip in ALLOWED_COMFORT_TIPS 
                       if any(source in tip.lower() for source in ["chinese medicine", "ayurveda", "tcm"])
                       and tip.lower() not in [t.lower() for t in recent_tips]]
        
        if not eastern_tips:
            # If all Eastern tips were recently used, expand to 60 days or use all if still none
            recent_tips_60 = _get_recent_tips(days=60, db_session=db_session)
            eastern_tips = [tip for tip in ALLOWED_COMFORT_TIPS 
                           if any(source in tip.lower() for source in ["chinese medicine", "ayurveda", "tcm"])
                           and tip.lower() not in [t.lower() for t in recent_tips_60]]
            # If still none, use all Eastern tips (very rare with 100+ tips)
            if not eastern_tips:
                eastern_tips = [tip for tip in ALLOWED_COMFORT_TIPS 
                               if any(source in tip.lower() for source in ["chinese medicine", "ayurveda", "tcm"])]
        
        if eastern_tips:
            # Shuffle for maximum variety
            shuffled_eastern = eastern_tips.copy()
            random.shuffle(shuffled_eastern)
            daily_comfort_tip = shuffled_eastern[0]
        else:
            # Fallback to any tip with medical source (excluding recently used - last 30 days)
            tips_with_sources = [tip for tip in ALLOWED_COMFORT_TIPS
                                if any(source in tip.lower() for source in ["western medicine", "chinese medicine", "ayurveda"])
                                and tip.lower() not in [t.lower() for t in recent_tips]]
            
            if not tips_with_sources:
                # Expand to 60 days if needed
                recent_tips_60 = _get_recent_tips(days=60, db_session=db_session)
                tips_with_sources = [tip for tip in ALLOWED_COMFORT_TIPS
                                    if any(source in tip.lower() for source in ["western medicine", "chinese medicine", "ayurveda"])
                                    and tip.lower() not in [t.lower() for t in recent_tips_60]]
                # If still none, use all tips with sources (very rare with 150+ tips)
                if not tips_with_sources:
                    tips_with_sources = [tip for tip in ALLOWED_COMFORT_TIPS
                                        if any(source in tip.lower() for source in ["western medicine", "chinese medicine", "ayurveda"])]
            
            if tips_with_sources:
                shuffled_sources = tips_with_sources.copy()
                random.shuffle(shuffled_sources)
                daily_comfort_tip = shuffled_sources[0]
            else:
                # Final fallback - exclude recent tips
                available_tips = [tip for tip in ALLOWED_COMFORT_TIPS 
                                if tip.lower() not in [t.lower() for t in recent_tips]]
                if not available_tips:
                    # If all tips were used, expand to 60 days
                    recent_tips_60 = _get_recent_tips(days=60, db_session=db_session)
                    available_tips = [tip for tip in ALLOWED_COMFORT_TIPS 
                                    if tip.lower() not in [t.lower() for t in recent_tips_60]]
                    # If still none, use all tips (extremely rare)
                    if not available_tips:
                        available_tips = ALLOWED_COMFORT_TIPS
                shuffled_all = available_tips.copy()
                random.shuffle(shuffled_all)
                daily_comfort_tip = shuffled_all[0]
        
        # Track this tip as used today
        if daily_comfort_tip:
            _track_comfort_tip(daily_comfort_tip)

    daily_sign_off = daily_sign_off or _choose_sign_off(user_diagnoses, location)

    # FINAL FALLBACK: Ensure we always have a comfort tip before formatting
    if not daily_comfort_tip:
        print("⚠️ Still no comfort tip before formatting - providing final fallback")
        recent_tips_list = _get_recent_tips(days=30, db_session=db_session)
        recent_tips_lower = [t.lower() for t in recent_tips_list]
        available_tips = [tip for tip in ALLOWED_COMFORT_TIPS if tip.lower() not in recent_tips_lower]
        daily_comfort_tip = random.choice(available_tips) if available_tips else random.choice(ALLOWED_COMFORT_TIPS)
        _track_comfort_tip(daily_comfort_tip)
    
    filtered_summary = _filter_app_messages(daily_summary) or daily_summary
    filtered_why_line = _filter_app_messages(daily_why_line) or daily_why_line
    filtered_comfort = _filter_app_messages(daily_comfort_tip) or daily_comfort_tip
    filtered_sign_off = _filter_app_messages(daily_sign_off) or daily_sign_off

    formatted_daily_message = _format_daily_message(
        filtered_summary,
        filtered_why_line,
        filtered_comfort,
        filtered_sign_off
    )

    if forecast_from_model:
        forecast = _filter_app_messages(forecast_from_model)
    else:
        forecast = _filter_app_messages(_choose_forecast(risk, severity_label))

    why_text = _filter_app_messages(daily_why_line) or _filter_app_messages(why_from_model) or ""

    support_note = _filter_app_messages(
        _choose_support_note(user_diagnoses, severity_label, signed_delta, direction, risk)
    )

    personal_anecdote = None
    normalized_diags = [d.lower() for d in (user_diagnoses or [])]
    if risk == "HIGH" and signed_delta <= -5:
        for diag in normalized_diags:
            if diag in PERSONAL_ANECDOTES:
                personal_anecdote = _filter_app_messages(random.choice(PERSONAL_ANECDOTES[diag]))
                break

    behavior_prompt = None
    if risk in {"MODERATE", "HIGH"} and random.random() < 0.5:
        behavior_prompt = _filter_app_messages(random.choice(BEHAVIOR_PROMPTS))

    personalization_score = _personalization_score(user_diagnoses, support_note, severity_label)

    if sources:
        sources = [s for s in sources if s]
    elif papers:
        # Enhanced citation formatting: "Title (Journal, Year)" or "Title - Journal" or just "Title"
        enhanced_sources = []
        for paper in papers:
            title = paper.get("title", "").strip()
            journal = paper.get("journal", "").strip()
            year = paper.get("year", "").strip()
            source_id = paper.get("source", "").strip()
            
            if not title:
                # Fallback to source ID if no title
                if source_id:
                    enhanced_sources.append(source_id)
                continue
            
            # Build enhanced citation
            citation_parts = [title]
            
            # Add journal and year if available
            if journal and journal != "Unknown journal":
                if year and year != "Unknown":
                    citation_parts.append(f"({journal}, {year})")
                else:
                    citation_parts.append(f"({journal})")
            elif year and year != "Unknown":
                citation_parts.append(f"({year})")
            
            # Join parts with space
            enhanced_citation = " ".join(citation_parts)
            enhanced_sources.append(enhanced_citation)
        
        sources = enhanced_sources if enhanced_sources else [
            paper.get("source") or paper.get("title")
            for paper in papers
            if paper.get("source") or paper.get("title")
        ]

    result = (
        risk,
        forecast or "",
        why_text or "",
        formatted_daily_message,
        sources or [],
        support_note,
        alert_severity,
        personalization_score,
        personal_anecdote,
        behavior_prompt
    )
    
    # Cache result if applicable (only for generic weather patterns without user-specific data)
    if use_cache and cache_key:
        import time
        _insight_cache[cache_key] = (time.time(), *result)
        # Clean up old cache entries (keep cache size reasonable)
        if len(_insight_cache) > 50:
            current_time = time.time()
            keys_to_remove = [
                key for key, (cached_time, *_) in _insight_cache.items()
                if (current_time - cached_time) > _CACHE_TTL_SECONDS
            ]
            for key in keys_to_remove:
                del _insight_cache[key]
    
    return result


# Backward compatibility function
def generate_insight_with_papers(
    correlations: Dict[str, float],
    symptom: str,
    weather_factor: str,
    papers: List[Dict[str, str]],
    user_diagnoses: Optional[List[str]] = None,
    all_symptoms: List[str] = None,
    current_weather: Optional[Dict[str, float]] = None,
    pressure_trend: Optional[str] = None,
    location: Optional[str] = None
) -> Tuple[str, List[str]]:
    """
    Generate AI insight with research papers (backward compatibility wrapper).
    
    Returns:
        Tuple of (ai_message, citations_list)
    """
    if current_weather is None:
        # Build current_weather from correlations (fallback)
        current_weather = {
            "pressure": 1013,
            "humidity": 50,
            "temperature": 20,
            "wind": 0,
            "condition": "Unknown"
        }
    
    _, _, _, full_message, citations, _, _, _, _, _, _ = generate_flare_risk_assessment(
        current_weather=current_weather,
        pressure_trend=pressure_trend,
        weather_factor=weather_factor,
        papers=papers,
        user_diagnoses=user_diagnoses,
        location=location
    )
    
    return (full_message, citations)


def generate_weekly_forecast_insight(
    weekly_forecast: List[Dict[str, float]],
    user_diagnoses: Optional[List[str]] = None,
    user_sensitivities: Optional[List[str]] = None,
    location: Optional[str] = None,
    today_risk_context: Optional[str] = None,
    today_pressure: Optional[float] = None,
    today_temp: Optional[float] = None,
    today_humidity: Optional[float] = None,
    pressure_trend: Optional[str] = None,
    tomorrow_expected_pressure: Optional[float] = None
) -> Tuple[str, List[str]]:
    """Generate a weekly outlook that follows the locked structure."""
    if not client:
        payload = json.dumps({
            "weekly_summary": "Weekly outlook is offline. Please check back soon.",
            "daily_breakdown": []
        })
        return (payload, [])

    if not weekly_forecast:
        payload = json.dumps({
            "weekly_summary": "Weekly forecast data is not available at this time.",
            "daily_breakdown": []
        })
        return (payload, [])

    forecast_entries = weekly_forecast[:7]
    if not forecast_entries:
        payload = json.dumps({
            "weekly_summary": "Weekly forecast data is not available at this time.",
            "daily_breakdown": []
        })
        return (payload, [])

    # Always start weekday labels from tomorrow (user's perspective)
    # Use the first entry's timestamp to get the user's timezone and calculate "tomorrow"
    # WeatherKit daily forecasts typically start with "today" (entry 0), so entry 1 is "tomorrow"
    # But we'll use entry 0's date + 1 day to get tomorrow in the user's timezone
    first_entry = forecast_entries[0]
    second_entry = forecast_entries[1] if len(forecast_entries) > 1 else None
    
    # Parse timestamps to get dates in user's timezone
    first_entry_datetime = None
    second_entry_datetime = None
    
    if "timestamp" in first_entry:
        try:
            timestamp_str = first_entry["timestamp"]
            if isinstance(timestamp_str, str):
                if timestamp_str.endswith("Z"):
                    timestamp_str = timestamp_str.replace("Z", "+00:00")
                parsed = datetime.fromisoformat(timestamp_str)
                # Keep the timezone info to preserve user's local timezone
                first_entry_datetime = parsed
                # Normalize to midnight in user's timezone
                if first_entry_datetime.tzinfo:
                    first_entry_datetime = first_entry_datetime.replace(hour=0, minute=0, second=0, microsecond=0)
                else:
                    first_entry_datetime = first_entry_datetime.replace(hour=0, minute=0, second=0, microsecond=0)
        except (ValueError, AttributeError, KeyError) as e:
            print(f"⚠️ Error parsing first forecast timestamp: {e}")
    
    if second_entry and "timestamp" in second_entry:
        try:
            timestamp_str = second_entry["timestamp"]
            if isinstance(timestamp_str, str):
                if timestamp_str.endswith("Z"):
                    timestamp_str = timestamp_str.replace("Z", "+00:00")
                parsed = datetime.fromisoformat(timestamp_str)
                second_entry_datetime = parsed
                if second_entry_datetime.tzinfo:
                    second_entry_datetime = second_entry_datetime.replace(hour=0, minute=0, second=0, microsecond=0)
                else:
                    second_entry_datetime = second_entry_datetime.replace(hour=0, minute=0, second=0, microsecond=0)
        except (ValueError, AttributeError, KeyError) as e:
            print(f"⚠️ Error parsing second forecast timestamp: {e}")
    
    # Calculate tomorrow: use second entry if available (entry 1 = tomorrow in WeatherKit)
    # Otherwise, use first entry + 1 day
    if second_entry_datetime:
        tomorrow_datetime = second_entry_datetime
        print(f"🔍 Weekly forecast: Using second entry as tomorrow: {tomorrow_datetime}")
    elif first_entry_datetime:
        # Calculate tomorrow as first entry + 1 day (preserving timezone)
        tomorrow_datetime = first_entry_datetime + timedelta(days=1)
        print(f"🔍 Weekly forecast: First entry={first_entry_datetime}, calculating tomorrow: {tomorrow_datetime}")
    else:
        # Fallback: use UTC (shouldn't happen)
        now_utc = datetime.utcnow()
        tomorrow_datetime = now_utc.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
        print(f"🔍 Weekly forecast: No entry dates, using fallback: {tomorrow_datetime}")
    
    # Convert to naive datetime for weekday calculation (timezone doesn't matter for day names)
    if tomorrow_datetime.tzinfo:
        tomorrow_datetime = tomorrow_datetime.replace(tzinfo=None)
    
    # Generate weekday labels starting from tomorrow
    weekday_labels = []
    for i in range(7):
        day = tomorrow_datetime + timedelta(days=i)
        weekday_labels.append(day.strftime("%a"))
        print(f"🔍   Day {i}: {day.strftime('%Y-%m-%d %A')}")
    
    # Use forecast entries directly - they should already start from tomorrow
    ordered_entries = forecast_entries[:len(weekday_labels)]

    while len(ordered_entries) < len(weekday_labels):
        ordered_entries.append(ordered_entries[-1])

    # Helper function to calculate risk based on weather factors, user diagnoses, and sensitivities
    def calculate_day_risk(
        pressure: float,
        prev_pressure: Optional[float],
        temp: float,
        prev_temp: Optional[float],
        humidity: float,
        prev_humidity: Optional[float],
        wind: float,
        diagnoses: Optional[List[str]],
        sensitivities: Optional[List[str]] = None
    ) -> tuple[str, list[str]]:
        """
        Calculate risk level and risk factors for a day based on weather changes and user diagnoses.
        Returns: (risk_level, risk_factors)
        """
        risk_factors = []
        risk_score = 0  # Accumulate risk points
        
        # Normalize diagnoses to lowercase for matching
        normalized_diags = [d.lower() for d in (diagnoses or [])]
        has_fibro = any("fibro" in d for d in normalized_diags)
        has_migraine = any("migraine" in d for d in normalized_diags)
        has_arthritis = any("arthrit" in d for d in normalized_diags)
        has_chronic_pain = any("chronic pain" in d or "chronic" in d for d in normalized_diags)
        # Chronic pain and arthritis share similar sensitivities to pressure changes
        has_pain_sensitivity = has_arthritis or has_chronic_pain
        
        # Normalize sensitivities to lowercase for matching
        normalized_sens = [s.lower() for s in (sensitivities or [])]
        has_pressure_sensitivity = any("pressure" in s for s in normalized_sens)
        has_humidity_sensitivity = any("humidity" in s for s in normalized_sens)
        has_temperature_sensitivity = any("temperature" in s or "temp" in s for s in normalized_sens)
        has_wind_sensitivity = any("wind" in s for s in normalized_sens)
        
        # 1. PRESSURE CHANGES (affects all conditions, especially migraines)
        if prev_pressure is not None:
            pressure_delta = pressure - prev_pressure
            abs_pressure_delta = abs(pressure_delta)
            
            # Pressure DROPS are especially problematic for arthritis/chronic pain
            is_pressure_drop = pressure_delta < 0  # Negative delta = dropping pressure
            
            # More sensitive thresholds - smaller changes should trigger risk
            if abs_pressure_delta >= 6:  # Lowered from 8
                risk_factors.append("rapid pressure shift")
                risk_score += 3  # High impact
                if has_migraine:
                    risk_score += 1  # Migraines especially sensitive to rapid pressure changes
                if is_pressure_drop and has_pain_sensitivity:
                    risk_score += 2  # Pressure drops are very triggering for arthritis/chronic pain
                if has_pressure_sensitivity:
                    risk_score += 2  # User has explicitly identified pressure as a trigger
            elif abs_pressure_delta >= 3:  # Lowered from 4
                risk_factors.append("noticeable pressure change")
                risk_score += 2  # Moderate impact
                if has_migraine:
                    risk_score += 1
                if is_pressure_drop and has_pain_sensitivity:
                    risk_score += 1  # Pressure drops trigger arthritis/chronic pain
                if has_pressure_sensitivity:
                    risk_score += 1  # User has explicitly identified pressure as a trigger
            elif abs_pressure_delta >= 1.5:  # Lowered from 2 - more sensitive
                risk_factors.append("slight pressure shift")
                risk_score += 1  # Low impact - but still triggers Moderate
                if is_pressure_drop and has_pain_sensitivity:
                    risk_score += 1  # Even small pressure drops can affect arthritis/chronic pain
                if has_pressure_sensitivity:
                    risk_score += 1  # User has explicitly identified pressure as a trigger
        else:
            risk_factors.append("pressure steadies")
        
        # 2. TEMPERATURE SWINGS (affects arthritis, fibromyalgia)
        if prev_temp is not None:
            temp_delta = temp - prev_temp
            abs_temp_delta = abs(temp_delta)
            
            # More sensitive thresholds
            if abs_temp_delta >= 6:  # Lowered from 8
                risk_factors.append("significant temperature swing")
                risk_score += 2
                if has_arthritis or has_fibro:
                    risk_score += 1  # Joint/muscle conditions sensitive to temp changes
                if has_temperature_sensitivity:
                    risk_score += 1  # User has explicitly identified temperature as a trigger
            elif abs_temp_delta >= 3:  # Lowered from 4
                risk_factors.append("moderate temperature change")
                risk_score += 1
                if has_arthritis:
                    risk_score += 1
                if has_temperature_sensitivity:
                    risk_score += 1  # User has explicitly identified temperature as a trigger
        
        # 3. HUMIDITY SWINGS (affects arthritis, fibromyalgia)
        if prev_humidity is not None:
            humidity_delta = humidity - prev_humidity
            abs_humidity_delta = abs(humidity_delta)
            
            # More sensitive thresholds
            if abs_humidity_delta >= 20:  # Lowered from 25
                risk_factors.append("major humidity swing")
                risk_score += 2
                if has_arthritis:
                    risk_score += 1  # Arthritis sensitive to humidity
                if has_humidity_sensitivity:
                    risk_score += 1  # User has explicitly identified humidity as a trigger
            elif abs_humidity_delta >= 12:  # Lowered from 15
                risk_factors.append("noticeable humidity change")
                risk_score += 1
                if has_arthritis:
                    risk_score += 1
                if has_humidity_sensitivity:
                    risk_score += 1  # User has explicitly identified humidity as a trigger
        
        # 4. EXTREME HUMIDITY LEVELS (absolute values matter too)
        if humidity >= 80:
            risk_factors.append("very high humidity")
            risk_score += 1
            if has_arthritis:
                risk_score += 1
        elif humidity <= 30:
            risk_factors.append("very dry air")
            risk_score += 1
        
        # 5. STORM FRONT DETECTION (rapid pressure drop + wind + humidity spike)
        # Classic storm front: pressure drops rapidly, wind increases, humidity rises
        is_storm_front = False
        if prev_pressure is not None:
            pressure_drop = prev_pressure - pressure  # Positive = dropping
            if pressure_drop >= 3 and wind >= 15 and humidity >= 60:  # Lowered thresholds
                is_storm_front = True
                risk_factors.append("storm front approaching")
                risk_score += 3  # Storm fronts are high risk
                if has_migraine:
                    risk_score += 2  # Migraines very sensitive to storm fronts
        
        # 6. COLD + HUMIDITY (arthritis trigger)
        if temp <= 10 and humidity >= 70:
            risk_factors.append("cold, damp conditions")
            risk_score += 1
            if has_arthritis:
                risk_score += 1
        
        # 7. RAPID WEATHER TRANSITIONS (multiple factors changing at once)
        # More sensitive thresholds for detecting multiple changes
        change_count = sum([
            abs_pressure_delta >= 1.5 if prev_pressure is not None else False,  # Lowered from 2
            abs_temp_delta >= 3 if prev_temp is not None else False,  # Lowered from 4
            abs_humidity_delta >= 12 if prev_humidity is not None else False  # Lowered from 15
        ])
        if change_count >= 2:
            risk_factors.append("multiple weather shifts")
            risk_score += 1  # Compound effect
        
        # 8. ABSOLUTE WEATHER CONDITIONS (even without previous values, extreme conditions matter)
        # If we don't have previous values, still check absolute conditions
        if prev_pressure is None and prev_temp is None and prev_humidity is None:
            # First day - check absolute conditions
            if humidity >= 80:
                risk_factors.append("very high humidity")
                risk_score += 1
                if has_arthritis:
                    risk_score += 1
            elif humidity <= 30:
                risk_factors.append("very dry air")
                risk_score += 1
            if temp <= 10 and humidity >= 70:
                risk_factors.append("cold, damp conditions")
                risk_score += 1
                if has_arthritis:
                    risk_score += 1
            if wind >= 25:
                risk_factors.append("strong winds")
                risk_score += 1
        
        # Convert risk score to risk level
        # Extremely aggressive thresholds to ensure variation in risk levels
        if risk_score >= 2:  # Lowered from 3 - High risk threshold (more aggressive)
            risk_level = "High"
        elif risk_score >= 0.5:  # Lowered from 1 - Any small change = at least Moderate (very aggressive)
            risk_level = "Moderate"
        else:
            # risk_score == 0: No changes detected, but check absolute conditions
            # Even "stable" conditions can be problematic if they're stable at bad levels
            # More aggressive: lower thresholds for absolute conditions
            if humidity >= 70:  # Lowered from 75 - high humidity is problematic
                risk_level = "Moderate"
                risk_factors.append("consistently high humidity")
            elif humidity <= 40:  # Lowered from 35 - very dry (more sensitive)
                risk_level = "Moderate"
                risk_factors.append("very dry conditions")
            elif temp <= 8 and humidity >= 60:  # Lowered thresholds - Cold and damp
                risk_level = "Moderate"
                risk_factors.append("cold, damp conditions")
            elif temp >= 28:  # Lowered from 30 - Very hot
                risk_level = "Moderate"
                risk_factors.append("very warm conditions")
            elif pressure <= 1005:  # Lowered from 1000 - Low pressure (more sensitive)
                risk_level = "Moderate"
                risk_factors.append("low pressure conditions")
            elif pressure >= 1025:  # Lowered from 1030 - High pressure (more sensitive)
                risk_level = "Moderate"
                risk_factors.append("high pressure conditions")
            else:
                # Truly stable and comfortable conditions - but still try to force variation elsewhere
                risk_level = "Low"
        
        print(f"🔍 calculate_day_risk result: risk_score={risk_score} → risk_level={risk_level}, factors={risk_factors}")
        return risk_level, risk_factors
    
    context_lines = ["Weekly Weather Notes:"]
    # Use today's values as baseline for tomorrow (first day of weekly forecast)
    # BUT: If pressure is dropping later today, use tomorrow's expected pressure instead
    # This accounts for pressure drops happening later today that will affect tomorrow
    if tomorrow_expected_pressure and pressure_trend and "drop" in pressure_trend.lower():
        # Pressure is dropping later today - use tomorrow's expected pressure for accurate comparison
        prev_pressure = tomorrow_expected_pressure
        print(f"📊 Weekly forecast: Pressure dropping later today ({pressure_trend}). Using tomorrow's expected pressure ({prev_pressure:.1f}hPa) as baseline")
    else:
        prev_pressure = today_pressure
        if prev_pressure:
            print(f"📊 Weekly forecast: Using today's pressure ({prev_pressure:.1f}hPa) as baseline for tomorrow's risk calculation")
        else:
            print(f"⚠️ Weekly forecast: today_pressure is None, using default 1013hPa")
            prev_pressure = 1013.0  # Default sea level pressure
    
    prev_temp = today_temp if today_temp is not None else 20.0  # Default 20°C
    prev_humidity = today_humidity if today_humidity is not None else 50.0  # Default 50%
    
    # Store baseline for forced variation logic
    baseline_pressure = prev_pressure
    baseline_temp = prev_temp
    baseline_humidity = prev_humidity
    
    print(f"📊 Weekly forecast baseline: pressure={prev_pressure:.1f}hPa, temp={prev_temp:.1f}°C, humidity={prev_humidity:.0f}%")
    day_risk_hints = []  # Track suggested risk levels based on data

    # Track all calculated risks to ensure variation
    calculated_risks = []  # List of (label, risk_level, risk_score, day_data)
    
    print(f"🔍 Starting weekly insight generation for {len(ordered_entries)} days")
    
    for label, day_data in zip(weekday_labels, ordered_entries):
        temp = day_data.get("temperature", 0)
        humidity = day_data.get("humidity", 0)
        wind = day_data.get("wind", 0)
        pressure = day_data.get("pressure", prev_pressure if prev_pressure is not None else 1013)
        
        # Validate we have actual data
        if temp == 0 and humidity == 0 and pressure == (prev_pressure if prev_pressure is not None else 1013):
            print(f"⚠️ Warning: Day {label} appears to have missing/invalid forecast data")

        # Calculate comprehensive risk based on all factors, user diagnoses, and sensitivities
        suggested_risk, risk_factors = calculate_day_risk(
            pressure=pressure,
            prev_pressure=prev_pressure,
            temp=temp,
            prev_temp=prev_temp,
            humidity=humidity,
            prev_humidity=prev_humidity,
            wind=wind,
            diagnoses=user_diagnoses,
            sensitivities=user_sensitivities
        )
        
        # Store calculated risk for variation check
        risk_score_approx = {"High": 3, "Moderate": 2, "Low": 1}.get(suggested_risk, 1)
        calculated_risks.append((label, suggested_risk, risk_score_approx, day_data))
        print(f"📝 Stored risk for {label}: {suggested_risk} (score: {risk_score_approx})")
        
        # Build descriptors from weather data
        descriptors = [_describe_temperature(temp)]
        humidity_desc = _describe_humidity(humidity)
        if humidity_desc:
            descriptors.append(humidity_desc)
        wind_desc = _describe_wind(wind)
        if wind_desc:
            descriptors.append(wind_desc)
        
        # Add pressure descriptor
        if prev_pressure is not None:
            delta = pressure - prev_pressure
            if abs(delta) >= 8:
                descriptors.append("pressure shifts sharply")
            elif abs(delta) >= 4:
                if delta < 0:
                    descriptors.append("pressure drops noticeably")
                else:
                    descriptors.append("pressure rises noticeably")
            elif abs(delta) >= 2:
                if delta < 0:
                    descriptors.append("pressure eases slightly")
                else:
                    descriptors.append("pressure builds slightly")
            else:
                descriptors.append("pressure steadies")
        else:
            descriptors.append("pressure steadies")
        
        descriptor_text = _combine_descriptors(*descriptors)
        risk_factors_str = ", ".join(risk_factors) if risk_factors else "stable conditions"
        context_lines.append(f"- {label}: {descriptor_text} [SUGGESTED RISK: {suggested_risk} - Factors: {risk_factors_str}]")
        day_risk_hints.append(suggested_risk)
        
        # Debug logging for risk calculation
        pressure_delta = pressure - prev_pressure if prev_pressure is not None else 0
        temp_delta = temp - prev_temp if prev_temp is not None else 0
        humidity_delta = humidity - prev_humidity if prev_humidity is not None else 0
        prev_pressure_str = f"{prev_pressure:.1f}" if prev_pressure is not None else "None"
        prev_temp_str = f"{prev_temp:.1f}" if prev_temp is not None else "None"
        prev_humidity_str = f"{prev_humidity:.0f}" if prev_humidity is not None else "None"
        print(f"📊 Weekly risk calc for {label}: temp={temp:.1f}°C (Δ{temp_delta:+.1f}), humidity={humidity:.0f}% (Δ{humidity_delta:+.0f}), pressure={pressure:.1f}hPa (Δ{pressure_delta:+.1f}), "
              f"prev_pressure={prev_pressure_str}hPa, "
              f"prev_temp={prev_temp_str}°C, "
              f"prev_humidity={prev_humidity_str}%, "
              f"risk={suggested_risk}, factors={risk_factors_str}")
        
        # Update previous values for next iteration
        prev_pressure = pressure
        prev_temp = temp
        prev_humidity = humidity
    
    # Count risk levels from calculated risks (based on actual weather data)
    all_low = all(risk == "Low" for _, risk, _, _ in calculated_risks)
    low_count = sum(1 for _, risk, _, _ in calculated_risks if risk == "Low")
    moderate_count = sum(1 for _, risk, _, _ in calculated_risks if risk == "Moderate")
    high_count = sum(1 for _, risk, _, _ in calculated_risks if risk == "High")
    
    print(f"📊 Risk summary (from actual weather data): {high_count} High, {moderate_count} Moderate, {low_count} Low")
    
    # Only force variation when there's actual evidence of weather variability:
    # 1. Today is High/Moderate risk (context suggests ongoing variability)
    # 2. There are actual weather changes in the forecast (pressure drops, temp swings, etc.)
    # 3. There are problematic absolute conditions (high humidity, low pressure, etc.)
    
    should_force_variation = False
    force_reason = []
    
    # Check if today's context suggests variability
    today_is_high = False
    today_is_moderate = False
    if today_risk_context:
        today_risk_lower = today_risk_context.lower()
        if "high" in today_risk_lower:
            today_is_high = True
            should_force_variation = True
            force_reason.append("today is High risk - forecast should reflect this")
        elif "moderate" in today_risk_lower:
            today_is_moderate = True
            # If today is Moderate but forecast shows all Low, that's inconsistent
            if all_low or (moderate_count + high_count) < 2:
                should_force_variation = True
                force_reason.append("today is Moderate risk but forecast shows insufficient variation")
    
    # Check if there are actual weather changes that warrant Moderate/High risk
    # Look for days with significant changes or problematic conditions
    def has_significant_weather_changes():
        """Check if forecast has actual weather changes that would justify Moderate/High risk."""
        significant_changes = 0
        for _, _, _, day_data in calculated_risks:
            temp = day_data.get("temperature", 0)
            humidity = day_data.get("humidity", 0)
            pressure = day_data.get("pressure", baseline_pressure if baseline_pressure else 1013)
            
            # Check for significant changes from baseline
            pressure_delta = abs(pressure - (baseline_pressure if baseline_pressure else 1013))
            temp_delta = abs(temp - (baseline_temp if baseline_temp else 20))
            humidity_delta = abs(humidity - (baseline_humidity if baseline_humidity else 50))
            
            # Check for problematic absolute conditions
            has_problematic_conditions = (
                humidity >= 75 or humidity <= 35 or  # Extreme humidity
                (temp <= 5 and humidity >= 65) or  # Cold and damp
                temp >= 30 or  # Very hot
                pressure <= 1000 or pressure >= 1030  # Extreme pressure
            )
            
            # Check for significant changes
            has_significant_changes = (
                pressure_delta >= 3 or  # 3+ hPa change
                temp_delta >= 4 or  # 4+ °C change
                humidity_delta >= 15  # 15+ % change
            )
            
            if has_problematic_conditions or has_significant_changes:
                significant_changes += 1
        
        return significant_changes
    
    significant_weather_days = has_significant_weather_changes()
    
    # If today is High risk, we need at least 3-4 Moderate/High days in the forecast
    # If today is Moderate risk, we need at least 2-3 Moderate/High days
    if today_is_high and (moderate_count + high_count) < 3:
        should_force_variation = True
        force_reason.append(f"today is High risk but only {moderate_count + high_count} Moderate/High days (need at least 3)")
    elif today_is_moderate and (moderate_count + high_count) < 2:
        should_force_variation = True
        force_reason.append(f"today is Moderate risk but only {moderate_count + high_count} Moderate/High days (need at least 2)")
    
    # Also check if there are actual significant weather changes but they're all showing as Low
    if all_low and significant_weather_days >= 3:
        should_force_variation = True
        force_reason.append(f"{significant_weather_days} days have significant weather changes but all showing Low")
    
    if should_force_variation and len(calculated_risks) > 0:
        print(f"⚠️ Forcing variation based on actual weather evidence: {', '.join(force_reason)}")
        
        # Find days with largest changes or problematic conditions (based on actual data)
        def calculate_change_magnitude(day_data_tuple):
            _, _, _, day_data = day_data_tuple
            temp = day_data.get("temperature", 0)
            humidity = day_data.get("humidity", 0)
            pressure = day_data.get("pressure", baseline_pressure if baseline_pressure else 1013)
            
            # Calculate deltas from baseline
            pressure_delta = abs(pressure - (baseline_pressure if baseline_pressure else 1013))
            temp_delta = abs(temp - (baseline_temp if baseline_temp else 20))
            humidity_delta = abs(humidity - (baseline_humidity if baseline_humidity else 50))
            
            # Consider absolute conditions that are problematic
            absolute_severity = 0
            if humidity >= 75:  # High humidity is problematic
                absolute_severity += 2
            elif humidity <= 35:  # Very dry is problematic
                absolute_severity += 1.5
            if temp <= 5 and humidity >= 65:  # Cold and damp
                absolute_severity += 2
            elif temp >= 30:  # Very hot
                absolute_severity += 1.5
            if pressure <= 1000:  # Low pressure
                absolute_severity += 1.5
            elif pressure >= 1030:  # Very high pressure
                absolute_severity += 1
            
            # Weighted sum of changes + absolute severity
            return (pressure_delta * 2 + temp_delta * 1.5 + humidity_delta * 0.5) + absolute_severity
        
        # Sort by change magnitude (descending) - only days with actual changes
        sorted_by_change = sorted(calculated_risks, key=calculate_change_magnitude, reverse=True)
        
        # Only force days that have actual weather changes (change_magnitude > 1.5)
        # Don't force days with truly stable conditions
        # BUT: If today is High risk, be more aggressive to ensure forecast reflects this
        forced_count = 0
        target_moderate_high = 3 if today_is_high else (2 if today_is_moderate else 0)
        current_moderate_high_after_force = moderate_count + high_count
        
        for i, day_tuple in enumerate(sorted_by_change):
            # If we've reached our target and today isn't High/Moderate, stop forcing
            if not today_is_high and not today_is_moderate and current_moderate_high_after_force >= target_moderate_high:
                break
            
            label, orig_risk, _, day_data = day_tuple
            change_mag = calculate_change_magnitude(day_tuple)
            
            # Only force if there's actual evidence (change or problematic conditions)
            # Lower threshold if today is High risk (be more aggressive)
            threshold = 1.0 if today_is_high else 1.5
            if change_mag > threshold:  # Threshold for actual weather significance
                # Determine risk based on actual change magnitude
                # If today is High, be more likely to assign High risk
                if change_mag >= 4 or (today_is_high and change_mag >= 2.5):
                    forced_risk = "High"
                elif change_mag >= 2:
                    forced_risk = "Moderate"
                else:
                    # Small change, keep as Low
                    continue
                
                # Only force if it's currently Low (don't downgrade Moderate/High)
                if orig_risk == "Low":
                    # Find and update in context_lines and day_risk_hints
                    for j, (orig_label, _, _, _) in enumerate(calculated_risks):
                        if orig_label == label:
                            # Update the hint
                            day_risk_hints[j] = forced_risk
                            # Update context line
                            for k, line in enumerate(context_lines):
                                if line.startswith(f"- {label}:"):
                                    # Replace the risk in the context line
                                    context_lines[k] = line.replace(f"[SUGGESTED RISK: {orig_risk}", f"[SUGGESTED RISK: {forced_risk}")
                                    break
                            print(f"🔧 Forced {label} from Low to {forced_risk} (change magnitude: {change_mag:.1f} - actual weather change)")
                            forced_count += 1
                            current_moderate_high_after_force += 1
                            # Stop if we've reached target (unless today is High and we need more)
                            if current_moderate_high_after_force >= target_moderate_high and not today_is_high:
                                break
                            break
        
        # Log summary of forced changes
        moderate_count = sum(1 for r in day_risk_hints if r == "Moderate")
        high_count = sum(1 for r in day_risk_hints if r == "High")
        print(f"📊 After forced variation (based on actual weather): {high_count} High, {moderate_count} Moderate, {len(day_risk_hints) - moderate_count - high_count} Low ({forced_count} days forced)")
    else:
        print(f"✅ No forced variation needed - risk levels reflect actual weather conditions")

    diagnoses_str = ", ".join(user_diagnoses) if user_diagnoses else "weather-sensitive conditions"
    sensitivities_str = ", ".join(user_sensitivities) if user_sensitivities else None
    location_note = f" near {location}" if location else ""
    weekday_clause = ", ".join(weekday_labels)
    
    # Build sensitivities context for prompt
    sensitivities_context = ""
    if sensitivities_str:
        sensitivities_context = f" Known weather triggers: {sensitivities_str} (prioritize these factors when determining risk levels and descriptors)."

    prompt_context = "\n".join(context_lines)
    
    # Add today's risk context if provided (helps maintain consistency)
    today_context = ""
    if today_risk_context:
        pressure_trend_note = ""
        if pressure_trend and "drop" in pressure_trend.lower():
            pressure_trend_note = f" Pressure is {pressure_trend} later today, which will affect tomorrow's conditions - tomorrow should reflect this change, not show Low risk."
        
        # Make today's context much more explicit and forceful
        risk_level = today_risk_context.lower()
        if "high" in risk_level:
            today_context = f"\n\nCRITICAL CONTEXT: {today_risk_context} This means conditions TODAY are challenging. The week ahead should reflect this - you MUST include Moderate and High risk days. DO NOT show all Low risk days when today is High risk.{pressure_trend_note} If today is High risk, at least 3-4 days this week should also be Moderate or High risk. The weather patterns are NOT all stable."
        elif "moderate" in risk_level:
            today_context = f"\n\nIMPORTANT CONTEXT: {today_risk_context} This means conditions TODAY have variability. The week ahead should reflect this - include Moderate risk days, not all Low.{pressure_trend_note} If today is Moderate risk, at least 2-3 days this week should also be Moderate or High risk."
        else:
            today_context = f"\n\nIMPORTANT CONTEXT: {today_risk_context}{pressure_trend_note} Consider this when determining risk levels for the week ahead."
    
    prompt = f"""You are FlareWeather, a calm weekly planning assistant for weather-sensitive people.

User context: {diagnoses_str}{location_note}.{sensitivities_context}

CRITICAL LANGUAGE RULES:
- Use grade 12 reading level vocabulary only - no made-up words, technical jargon, or obscure terms.
- If you're unsure if a word is too complex, use a simpler alternative.
- Never use words that don't exist in standard dictionaries.
- Use plain, everyday language that anyone can understand.

CRITICAL REQUIREMENT: You MUST mention the user's specific conditions or sensitivities in the daily blurbs when the weather matches their triggers. Do NOT give generic descriptions. Personalize each day's descriptor to their situation. EXAMPLES: If user has arthritis and humidity is high: "Moderate risk — high humidity may increase joint stiffness for those with arthritis" or "High risk — damp conditions could be challenging for arthritis." If user has migraines and pressure is dropping: "Moderate risk — pressure drop may trigger headaches if you experience migraines" or "High risk — rapid pressure shift could activate migraine sensitivity." If user has pressure sensitivity: "Moderate risk — pressure shift may be noticeable if pressure changes affect you." If user has multiple conditions, mention the most relevant one for that day's weather. Keep it conversational and non-medical - reference their triggers naturally.

{prompt_context}{today_context}

Use the weekday order exactly as provided: {weekday_clause}.

RISK LEVEL DETERMINATION (USE THE SUGGESTED RISK LEVELS PROVIDED):
The suggested risk levels are calculated based on:
- Pressure changes (affects all conditions, especially migraines)
- Temperature swings (affects arthritis, fibromyalgia)
- Humidity swings (affects arthritis, fibromyalgia)
- Storm fronts (rapid pressure drop + wind + humidity - especially triggers migraines)
- Extreme humidity levels (very high/low)
- Cold + damp conditions (arthritis trigger)
- Multiple simultaneous weather shifts (compound effect)

RISK LEVELS:
- LOW RISK: Stable conditions, minimal changes across all factors
- MODERATE RISK: Noticeable changes in one or more factors, or moderate changes in multiple factors
- HIGH RISK: Rapid/large changes, storm fronts, or multiple significant shifts happening together

CRITICAL: Each day's weather data includes a [SUGGESTED RISK: X - Factors: ...] hint calculated from actual weather data AND your specific conditions ({diagnoses_str}). 

ABSOLUTE REQUIREMENT: You MUST use the exact risk level from the [SUGGESTED RISK] hint. DO NOT override it or default to Low.
- If the hint says "High", you MUST use "High risk" for that day - NO EXCEPTIONS
- If the hint says "Moderate", you MUST use "Moderate risk" for that day - NO EXCEPTIONS  
- Only use "Low risk" if the hint explicitly says "Low"

CRITICAL: If you see multiple [SUGGESTED RISK: Moderate] or [SUGGESTED RISK: High] hints in the weather data, you MUST use those risk levels. DO NOT change them to Low. The risk calculation is based on actual weather data and your conditions - trust it.

VALIDATION: Before returning your response, verify that you used the exact risk levels from the [SUGGESTED RISK] hints. If you see "Moderate" or "High" in the hints, those days MUST show "Moderate risk" or "High risk" in your output, NOT "Low risk". If you return all Low risk when hints say Moderate/High, your response will be rejected and replaced.

DO NOT default to Low risk for all days. The risk calculation considers your specific sensitivities ({diagnoses_str}) and all weather factors, not just pressure. The suggested risks are calculated from real weather data - trust them and use them exactly as provided.

CRITICAL VARIATION REQUIREMENT: Even if weather appears stable, you MUST provide meaningful variation across the week. If you see multiple "Low" risk days, you MUST use different descriptors for each day from the approved list. NEVER use the same descriptor twice. If all days are Low risk, rotate through ALL the Low risk descriptors to ensure each day feels unique and valuable to the user.

CRITICAL: You are generating daily descriptors for weekly insights. Each day must have a risk level (Low, Moderate, or High) and a short descriptor following STRICT rules.

STRUCTURE: Weekday — Risk Level — descriptor (3-6 words after risk label)

STRICT RULES:
1. KEEP IT SHORT: 3-6 words after the risk label
2. NO MEDICAL CLAIMS: No "reduce," "treat," "prevent," "cause," "trigger," "flare," "symptom spikes"
3. WELLNESS-SAFE wording ONLY - use approved phrases below
4. NO VAGUE PHRASES: ABSOLUTELY FORBIDDEN - "a bit more", "a bit", "bit more", "more", "a bit easier", "a bit achy", "bit achy", "may feel different," "supportive," "gentle shift," "things may feel off", "more stable", "at ease", "more balanced", "steady conditions", "gentle conditions", "balanced conditions"
5. NO WEATHER NUMBERS: No pressure values, temps, humidity %, wind speeds
6. EACH DAY MUST BE UNIQUE - even if all days are "Low," descriptors MUST vary
7. LANGUAGE LEVEL: Use grade 12 reading level vocabulary only - no made-up words, technical jargon, or obscure terms. Never use words that don't exist in standard dictionaries.
8. MENTION CONDITIONS/SENSITIVITIES: If the user has specific conditions (e.g., arthritis, migraines, fibromyalgia) or sensitivities (e.g., pressure shifts, humidity changes), reference them naturally in the descriptors when relevant (e.g., "pressure-sensitive day" or "arthritis-aware shift")
9. VALIDATION: Before returning your response, check EVERY descriptor. If ANY descriptor contains "a bit", "bit more", "more", "a bit easier", "a bit achy", or any other vague phrase not in the approved lists, you MUST replace it with an approved descriptor from the lists above. DO NOT return vague phrases.

RISK LEVEL RULES:

LOW RISK DAYS:
- Always begin with: "Low flare risk —"
- Then choose ONE descriptor from THIS EXACT LIST ONLY - YOU MUST ROTATE THROUGH ALL OPTIONS, never repeat:
  * "steady pressure"
  * "stable pattern"
  * "predictable day"
  * "cool, calm air"
  * "gentle humidity"
  * "smooth conditions"
  * "easy-going pattern"
  * "low-impact day"
  * "calm weather pattern"
  * "settled weather"
  * "consistent pattern"
- FORBIDDEN vague descriptors (DO NOT USE): "more stable", "at ease", "more balanced", "steady conditions", "gentle conditions", "balanced conditions", or any other phrases not in the approved list above
- CRITICAL: Even if multiple days are Low risk, each MUST have a DIFFERENT descriptor from the approved list. Never use the same descriptor twice in one week.

MODERATE RISK DAYS:
- Always begin with: "Moderate risk —"
- Then choose ONE descriptor from THIS EXACT LIST ONLY (vary across days):
  * "noticeable pressure shifts"
  * "light stiffness possible"
  * "mixed weather patterns"
  * "variable conditions ahead"
  * "pressure changes expected"
  * "shifting weather pattern"
  * "unsettled conditions"
  * "changing pressure trend"
  * "moderate weather shifts"
  * "transitional conditions"
  * "pressure fluctuations"
  * "weather pattern shifts"
- FORBIDDEN vague descriptors (DO NOT USE): "slightly effortful", "mild body sensitivity", "more activating", "less predictable", "mild discomfort", "a bit achy", "bit achy", "achy", "slightly uncomfortable", or any vague/medical-sounding phrases not in the approved list above

HIGH RISK DAYS:
- Always begin with: "High risk —"
- Then choose ONE descriptor from THIS EXACT LIST ONLY (vary across days):
  * "draining conditions"
  * "unstable pattern"
  * "heavier-feeling weather"
  * "high-variability pattern"
  * "challenging conditions"
  * "tense, activating shift"
  * "rapid pressure changes"
  * "significant weather shifts"
  * "unsettled weather pattern"
  * "major pressure fluctuations"
  * "storm front conditions"
  * "dramatic weather changes"
- FORBIDDEN vague descriptors (DO NOT USE): "stronger body sensitivity", "more demanding", "a bit achy", "bit achy", "achy", or any vague/medical-sounding phrases not in the approved list above

Return JSON EXACTLY:
{{
  "weekly_summary": "REQUIRED FORMAT: '[Overall weekly weather pattern description] which could [impact statement].' You MUST include both parts: 1) describe the overall weekly weather pattern (shifting pressures, humidity trends, temperature changes, wind patterns, etc.) 2) ALWAYS end with 'which could [impact]' - describe potential body impacts personalized to the user's conditions/sensitivities. CRITICAL: If the user has specific conditions or sensitivities, you MUST mention them in the summary. EXAMPLES: If user has arthritis: 'The week ahead brings dropping pressure midweek with rising humidity which could increase joint stiffness and inflammation for those with arthritis, so planning lighter activities midweek may help.' If user has migraines: 'Pressure shifts throughout the week which could trigger headaches if you experience migraines, especially midweek when changes are most rapid.' If user has pressure sensitivity: 'Multiple pressure shifts this week which could be noticeable if pressure changes affect you, with the most significant change midweek.' Never just describe weather alone. One to two sentences, no numbers, no greetings. Always include a brief actionable preparation note.",
  "daily_patterns": [
    {{"risk": "Low|Moderate|High", "descriptor": "MUST include full phrase like 'Low flare risk — steady pressure' or 'Moderate risk — slightly effortful conditions' or 'High risk — draining conditions'. The descriptor MUST include both the risk level prefix AND the descriptor text after the dash. CRITICAL: When the weather matches the user's triggers, you MUST reference their conditions/sensitivities in the descriptor. EXAMPLES: If user has arthritis and humidity is high: 'Moderate risk — high humidity may increase joint stiffness' or 'High risk — damp conditions challenging for arthritis.' If user has migraines and pressure is dropping: 'Moderate risk — pressure drop may trigger headaches' or 'High risk — rapid pressure shift activates migraine sensitivity.' If user has pressure sensitivity: 'Moderate risk — pressure shift noticeable if pressure changes affect you.' If weather doesn't match their triggers, use the approved descriptors from the list. Each day must be unique."}},
    ... (7 total entries, each UNIQUE descriptor)
  ],
  "sources": ["Optional short source names"],
  "preparation_tip": "REQUIRED: Provide a specific, actionable preparation suggestion for the week personalized to the user's conditions/sensitivities and the week's weather pattern. Make it practical and helpful. EXAMPLES: If user has arthritis and humidity is rising: 'Consider planning lighter activities for midweek when humidity peaks, and staying warm may help ease joint stiffness.' If user has migraines and pressure is shifting: 'Pressure changes midweek may be most noticeable - consider having your usual comfort measures ready and planning rest time.' If user has pressure sensitivity: 'The most significant pressure shift happens midweek - planning ahead for that day may help you manage any discomfort.' If multiple challenging days: 'Several days this week have noticeable shifts - consider pacing activities and having comfort measures ready.' Always make it specific to their conditions and the week's pattern. Keep it brief (1-2 sentences) and actionable."
}}

EXAMPLES:
- {{"risk": "Low", "descriptor": "Low flare risk — stable pattern"}}
- {{"risk": "Low", "descriptor": "Low flare risk — gentle humidity"}}
- {{"risk": "Moderate", "descriptor": "Moderate risk — light stiffness possible"}}
- {{"risk": "High", "descriptor": "High risk — draining conditions"}}

CRITICAL RULES:
1. Use ONLY the approved descriptors listed above. Do NOT create new phrases or use vague language like "more stable", "at ease", "more balanced", "steady conditions", "a bit more", "a bit", "bit more", "more", "a bit easier", "a bit achy", "bit achy", or ANY other phrases not explicitly in the approved lists.
2. Vary selections so each day is unique - NEVER repeat the same descriptor in one week.
3. If multiple days have the same risk level, you MUST use different descriptors for each.
4. Rotate through all available descriptors before repeating any.
5. Even if all 7 days are "Low" risk, each must have a completely different descriptor from the approved list.
6. If you use a descriptor not in the approved list, the response will be rejected. Stick to the exact phrases provided.
7. FORBIDDEN vague phrases that will cause rejection: "a bit more", "a bit", "bit more", "more", "a bit easier", "a bit achy", "bit achy", "more stable", "at ease", "more balanced", "steady conditions", "gentle conditions", "balanced conditions", "supportive", "moody", "unusual", "relaxed", "relaxing", "may feel", "might notice", "may sense", "might experience", "could help", "may help", "might help".
8. If you cannot find an appropriate approved descriptor, use the closest match from the approved list - NEVER invent new phrases.

EXAMPLE OF GOOD VARIATION (all Low risk but different):
- Day 1: "Low flare risk — steady pressure"
- Day 2: "Low flare risk — stable pattern"  
- Day 3: "Low flare risk — predictable day"
- Day 4: "Low flare risk — cool, calm air"
- Day 5: "Low flare risk — gentle humidity"
- Day 6: "Low flare risk — smooth conditions"
- Day 7: "Low flare risk — easy-going pattern"

BAD EXAMPLE (repeating):
- Day 1: "Low flare risk — steady pressure"
- Day 2: "Low flare risk — steady pressure"  ❌ WRONG - REPEATED
- Day 3: "Low flare risk — stable pattern"
"""

    # Try Claude Haiku first (faster), fall back to OpenAI
    response_data = None
    
    weekly_system_prompt = "You produce calm weekly outlooks in plain language and valid JSON. CRITICAL RULES: 1) Each daily_pattern descriptor MUST include BOTH the risk level prefix AND the descriptive text after the dash. Example: 'Low flare risk — steady pressure' NOT just 'Low flare risk'. 2) You MUST use ONLY the approved descriptors from the lists provided - NEVER create new phrases. 3) ABSOLUTELY FORBIDDEN vague phrases: 'a bit more', 'a bit', 'bit more', 'more', 'a bit easier', 'a bit achy', 'bit achy', 'more stable', 'at ease', 'more balanced', 'steady conditions'. 4) If you use any vague phrase not in the approved lists, your response will be rejected. 5) The descriptor after the dash is REQUIRED and provides value to users - use approved phrases only. 6) MOST IMPORTANT: You MUST use the exact risk level from [SUGGESTED RISK: X] hints in the weather data. If a hint says 'Moderate' or 'High', you MUST use that risk level - DO NOT default to 'Low'. Your response will be rejected if you ignore the suggested risk levels. Always respond with valid JSON only."
    
    if claude_client:
        try:
            print("🚀 Attempting Claude Haiku for weekly insight (faster)...")
            json_prompt = prompt + "\n\nIMPORTANT: Respond ONLY with valid JSON. Do not include any text before or after the JSON object. The JSON must match the exact structure specified above."
            
            message = claude_client.messages.create(
                model="claude-3-5-haiku-20241022",
                max_tokens=800,  # Weekly insights need more tokens
                temperature=0.5,
                system=weekly_system_prompt,
                messages=[{"role": "user", "content": json_prompt}]
            )
            response_text = message.content[0].text.strip()
            
            # Try to extract JSON if Claude added markdown formatting
            if "```json" in response_text:
                response_text = response_text.split("```json")[1].split("```")[0].strip()
            elif "```" in response_text:
                response_text = response_text.split("```")[1].split("```")[0].strip()
            
            response_data = json.loads(response_text)
            print(f"✅ Claude Haiku weekly insight received")
        except json.JSONDecodeError as e:
            print(f"⚠️  Claude weekly response not valid JSON, trying OpenAI: {e}")
            response_data = None
        except Exception as e:
            print(f"⚠️  Claude weekly API error, falling back to OpenAI: {e}")
            response_data = None
    
    if response_data is None and client:
        try:
            print("🔄 Using OpenAI gpt-4o-mini for weekly insight (fallback)...")
            completion = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": weekly_system_prompt},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.5,
                response_format={"type": "json_object"}
            )
            response_text = completion.choices[0].message.content.strip().strip("` ")
            response_data = json.loads(response_text)
        except Exception as exc:  # noqa: BLE001
            print(f"❌ Error generating weekly forecast insight: {exc}")
            import traceback
            traceback.print_exc()
            fallback = json.dumps({
                "weekly_summary": "Weekly outlook is unavailable right now.",
                "daily_breakdown": []
            })
            return (fallback, [])
    
    if response_data is None:
        fallback = json.dumps({
            "weekly_summary": "Weekly outlook is unavailable right now.",
            "daily_breakdown": []
        })
        return (fallback, [])

    weekly_summary = response_data.get("weekly_summary", "").strip()
    weekly_summary = _filter_app_messages(weekly_summary) or weekly_summary

    patterns = response_data.get("daily_patterns", [])
    if not isinstance(patterns, list):
        patterns = []

    sources = response_data.get("sources", []) or []
    
    print(f"📥 AI returned {len(patterns)} daily patterns")
    for i, p in enumerate(patterns):
        print(f"   Day {i}: risk={p.get('risk', 'Low')}, descriptor='{p.get('descriptor', '')[:50]}...'")

    # Default fallback patterns using approved descriptors - expanded list for variety
    # NOTE: "steady conditions" is FORBIDDEN - removed from all fallbacks
    low_fallbacks = [
        "Low flare risk — stable pressure",
        "Low flare risk — predictable day",
        "Low flare risk — cool, calm air",
        "Low flare risk — gentle humidity",
        "Low flare risk — smooth conditions",
        "Low flare risk — easy-going pattern",
        "Low flare risk — low-impact day",
        "Low flare risk — calm weather pattern",
        "Low flare risk — settled weather",
        "Low flare risk — consistent pattern",
        "Low flare risk — quiet weather day",
        "Low flare risk — unchanging conditions",
        "Low flare risk — even pressure pattern",
        "Low flare risk — balanced conditions",
        "Low flare risk — comfortable pattern",
        "Low flare risk — gentle weather day"
    ]
    moderate_fallbacks = [
        "Moderate risk — noticeable pressure shifts",
        "Moderate risk — light stiffness possible",
        "Moderate risk — mixed weather patterns",
        "Moderate risk — variable conditions ahead",
        "Moderate risk — pressure changes expected",
        "Moderate risk — shifting weather pattern",
        "Moderate risk — unsettled conditions",
        "Moderate risk — changing pressure trend",
        "Moderate risk — moderate weather shifts",
        "Moderate risk — transitional conditions",
        "Moderate risk — pressure fluctuations",
        "Moderate risk — weather pattern shifts"
    ]
    high_fallbacks = [
        "High risk — draining conditions",
        "High risk — unstable pattern",
        "High risk — heavier-feeling weather",
        "High risk — high-variability pattern",
        "High risk — challenging conditions",
        "High risk — rapid pressure changes",
        "High risk — significant weather shifts",
        "High risk — storm front conditions",
        "High risk — unsettled weather pattern",
        "High risk — major pressure fluctuations",
        "High risk — dramatic weather changes"
    ]

    while len(patterns) < len(weekday_labels):
        patterns.append({"risk": "Low", "descriptor": random.choice(low_fallbacks)})
    if len(patterns) > len(weekday_labels):
        patterns = patterns[:len(weekday_labels)]

    # CRITICAL: Validate that AI used the forced risk levels
    # If we forced variation but AI returned all Low, reject and use fallbacks with forced risks
    all_low_in_response = all(entry.get("risk", "Low").strip().lower() == "low" for entry in patterns)
    low_count_in_response = sum(1 for entry in patterns if entry.get("risk", "Low").strip().lower() == "low")
    
    # Also check if we have forced risks that should be used
    moderate_hints = sum(1 for r in day_risk_hints if r == "Moderate")
    high_hints = sum(1 for r in day_risk_hints if r == "High")
    
    # ALWAYS check: If we have forced Moderate/High hints but AI returned mostly Low, replace
    # Also check for "steady conditions" or similar forbidden phrases in descriptors
    forbidden_phrases = ["steady conditions", "steady pattern", "steady trend", "all steady", "all low"]
    has_forbidden_phrases = any(
        any(phrase in str(entry.get("descriptor", "")).lower() for phrase in forbidden_phrases)
        for entry in patterns
    )
    
    # CRITICAL: If we have forced hints, ALWAYS validate and replace if AI ignored them
    # EXTREMELY aggressive: replace if more than 1 Low day when we have forced hints (we force 5 Moderate/High)
    # Also replace if AI didn't match the forced risk hints
    ai_ignored_hints = False
    if len(day_risk_hints) > 0 and len(patterns) == len(day_risk_hints):
        # Check if AI risk levels match forced hints
        mismatches = 0
        for i, (hint, pattern) in enumerate(zip(day_risk_hints, patterns)):
            pattern_risk = pattern.get("risk", "Low").strip().lower()
            if hint == "High" and pattern_risk != "high":
                mismatches += 1
            elif hint == "Moderate" and pattern_risk != "moderate":
                mismatches += 1
        # If AI ignored ANY forced hints, replace (very aggressive)
        if mismatches > 0:
            ai_ignored_hints = True
            print(f"⚠️ AI ignored {mismatches} forced risk hints (out of {moderate_hints + high_hints} forced) - will replace with fallbacks")
    
    # EXTREMELY aggressive replacement: replace if we have ANY forced hints and AI didn't match them
    # OR if more than 1 Low day (since we force 5 Moderate/High, only 2 Low max)
    # OR if forbidden phrases like "steady conditions" appear
    should_replace = (all_low_in_response or low_count_in_response > 1 or has_forbidden_phrases or ai_ignored_hints) and len(day_risk_hints) > 0 and (moderate_hints > 0 or high_hints > 0)
    
    if should_replace:
        reason = []
        if all_low_in_response: reason.append("all Low")
        if low_count_in_response > 1: reason.append(f"{low_count_in_response} Low days (max 2 allowed)")
        if has_forbidden_phrases: reason.append("forbidden phrases like 'steady conditions'")
        if ai_ignored_hints: reason.append(f"AI ignored {mismatches} forced risk hints")
        print(f"❌ AI ignored forced risks ({moderate_hints} Moderate, {high_hints} High hints provided, but: {', '.join(reason)}). Replacing with fallbacks that respect suggested risks.")
        # Replace patterns with fallbacks that match the forced risk hints
        # Ensure unique descriptors by tracking used ones
        patterns = []
        used_fallbacks = set()
        
        # Shuffle fallback lists to ensure variety
        import random
        shuffled_high = high_fallbacks.copy()
        shuffled_moderate = moderate_fallbacks.copy()
        shuffled_low = low_fallbacks.copy()
        random.shuffle(shuffled_high)
        random.shuffle(shuffled_moderate)
        random.shuffle(shuffled_low)
        
        high_idx = 0
        moderate_idx = 0
        low_idx = 0
        
        for i, (label, risk_hint) in enumerate(zip(weekday_labels, day_risk_hints)):
            if risk_hint == "High":
                # Cycle through high fallbacks
                descriptor = shuffled_high[high_idx % len(shuffled_high)]
                high_idx += 1
            elif risk_hint == "Moderate":
                # Cycle through moderate fallbacks
                descriptor = shuffled_moderate[moderate_idx % len(shuffled_moderate)]
                moderate_idx += 1
            else:
                # Cycle through low fallbacks
                descriptor = shuffled_low[low_idx % len(shuffled_low)]
                low_idx += 1
            
            # Ensure uniqueness - if we've used this descriptor, try next one
            while descriptor in used_fallbacks:
                if risk_hint == "High":
                    descriptor = shuffled_high[high_idx % len(shuffled_high)]
                    high_idx += 1
                elif risk_hint == "Moderate":
                    descriptor = shuffled_moderate[moderate_idx % len(shuffled_moderate)]
                    moderate_idx += 1
                else:
                    descriptor = shuffled_low[low_idx % len(shuffled_low)]
                    low_idx += 1
            
            used_fallbacks.add(descriptor)
            patterns.append({"risk": risk_hint, "descriptor": descriptor})
        print(f"✅ Replaced with fallbacks: {sum(1 for p in patterns if p.get('risk') == 'High')} High, {sum(1 for p in patterns if p.get('risk') == 'Moderate')} Moderate")

    daily_breakdown: List[Dict[str, str]] = []
    used_descriptors = set()  # Track used descriptors to enforce variation
    
    for label, entry in zip(weekday_labels, patterns):
        # New format: risk and descriptor
        risk = entry.get("risk", "Low").strip()
        descriptor = entry.get("descriptor", "")
        
        # Fallback to old format if needed for backward compatibility
        if not descriptor:
            weather_pattern = entry.get("weather_pattern", "stable pattern")
            body_feel = entry.get("body_feel", "may feel stable on the body")
            if weather_pattern and body_feel:
                descriptor = f"{weather_pattern} — {body_feel}"
            else:
                # Use fallback based on risk
                if risk.upper() == "HIGH":
                    descriptor = random.choice(high_fallbacks)
                elif risk.upper() == "MODERATE":
                    descriptor = random.choice(moderate_fallbacks)
                else:
                    descriptor = random.choice(low_fallbacks)
        
        descriptor = _filter_app_messages(descriptor) or descriptor
        
        # VALIDATION: Reject vague descriptors not in approved list
        # Includes "steady conditions", "steady pattern", "steady trend" - all forbidden
        vague_forbidden = [
            "more stable", "at ease", "more balanced", "steady conditions", "steady pattern", "steady trend",
            "gentle conditions", "balanced conditions", "more predictable", "all steady", "all low",
            "easier day", "calmer day", "better conditions", "a bit easier",
            "bit easier", "easier", "slightly easier", "somewhat easier",
            "a bit achy", "bit achy", "achy", "slightly uncomfortable",
            "mild body sensitivity", "slightly effortful", "more activating",
            "less predictable", "mild discomfort", "stronger body sensitivity",
            "more demanding"
        ]
        descriptor_after_dash = ""
        if " — " in descriptor:
            descriptor_after_dash = descriptor.split(" — ", 1)[1].lower().strip()
        elif " - " in descriptor:
            descriptor_after_dash = descriptor.split(" - ", 1)[1].lower().strip()
        
        # Check if descriptor contains forbidden vague phrases (check full descriptor too, not just after dash)
        descriptor_lower = descriptor.lower()
        if any(vague in descriptor_after_dash for vague in vague_forbidden) or any(vague in descriptor_lower for vague in vague_forbidden):
            print(f"⚠️ Rejecting vague descriptor: '{descriptor}' - replacing with approved fallback")
            # Replace with approved fallback based on risk, ensuring uniqueness
            if risk.upper() == "HIGH":
                descriptor = random.choice([d for d in high_fallbacks if d not in used_descriptors] or high_fallbacks)
            elif risk.upper() == "MODERATE":
                descriptor = random.choice([d for d in moderate_fallbacks if d not in used_descriptors] or moderate_fallbacks)
            else:
                descriptor = random.choice([d for d in low_fallbacks if d not in used_descriptors] or low_fallbacks)
        
        # Ensure descriptor follows the format: "Risk Level — descriptor"
        if not descriptor.startswith(("Low flare risk", "Moderate risk", "High risk")):
            # Auto-add risk prefix if missing
            if risk.upper() == "HIGH":
                if not descriptor.startswith("High risk"):
                    descriptor = f"High risk — {descriptor}"
            elif risk.upper() == "MODERATE":
                if not descriptor.startswith("Moderate risk"):
                    descriptor = f"Moderate risk — {descriptor}"
            else:
                if not descriptor.startswith("Low flare risk"):
                    descriptor = f"Low flare risk — {descriptor}"
        
        # ENFORCE VARIATION: If this descriptor was already used, replace it
        descriptor_lower = descriptor.lower()
        if descriptor_lower in used_descriptors:
            # Find an unused alternative based on risk level
            if risk.upper() == "HIGH":
                available = [d for d in high_fallbacks if d.lower() not in used_descriptors]
                if available:
                    descriptor = random.choice(available)
                else:
                    # All used, reset and pick randomly
                    descriptor = random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                available = [d for d in moderate_fallbacks if d.lower() not in used_descriptors]
                if available:
                    descriptor = random.choice(available)
                else:
                    descriptor = random.choice(moderate_fallbacks)
            else:
                # Low risk - most common, need most variety
                available = [d for d in low_fallbacks if d.lower() not in used_descriptors]
                if available:
                    descriptor = random.choice(available)
                else:
                    # All used, reset and pick randomly
                    descriptor = random.choice(low_fallbacks)
        
        # VALIDATION: Ensure descriptor has actual descriptive content after the dash
        # If it's just "Low flare risk" or "Low flare risk —" with nothing after, add a descriptor
        if descriptor.lower().strip() in ["low flare risk", "moderate risk", "high risk"]:
            # Missing descriptor part - add one based on risk level
            if risk.upper() == "HIGH":
                descriptor = random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                descriptor = random.choice(moderate_fallbacks)
            else:
                descriptor = random.choice(low_fallbacks)
        elif " — " in descriptor and descriptor.split(" — ", 1)[1].strip() == "":
            # Has dash but no descriptor after it
            if risk.upper() == "HIGH":
                descriptor = random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                descriptor = random.choice(moderate_fallbacks)
            else:
                descriptor = random.choice(low_fallbacks)
        elif not " — " in descriptor and descriptor.lower().startswith(("low flare risk", "moderate risk", "high risk")):
            # Has risk level but no dash/descriptor - add one
            if risk.upper() == "HIGH":
                descriptor = random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                descriptor = random.choice(moderate_fallbacks)
            else:
                descriptor = random.choice(low_fallbacks)
        
        # ENFORCE VARIATION: If this descriptor was already used, replace it
        descriptor_lower = descriptor.lower()
        if descriptor_lower in used_descriptors:
            # Find an unused alternative based on risk level
            if risk.upper() == "HIGH":
                available = [d for d in high_fallbacks if d.lower() not in used_descriptors]
                if available:
                    descriptor = random.choice(available)
                else:
                    # All used, reset and pick randomly
                    descriptor = random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                available = [d for d in moderate_fallbacks if d.lower() not in used_descriptors]
                if available:
                    descriptor = random.choice(available)
                else:
                    descriptor = random.choice(moderate_fallbacks)
            else:
                # Low risk - most common, need most variety
                available = [d for d in low_fallbacks if d.lower() not in used_descriptors]
                if available:
                    descriptor = random.choice(available)
                else:
                    # All used, reset and pick randomly
                    descriptor = random.choice(low_fallbacks)
        
        # Track this descriptor as used
        used_descriptors.add(descriptor.lower())
        
        # Final validation: ensure format is correct
        if not " — " in descriptor:
            # Missing dash - add it
            if descriptor.lower().startswith("low flare risk"):
                base = "Low flare risk"
                desc_part = descriptor[len("Low flare risk"):].strip()
                if desc_part:
                    descriptor = f"{base} — {desc_part}"
                else:
                    descriptor = random.choice(low_fallbacks)
            elif descriptor.lower().startswith("moderate risk"):
                base = "Moderate risk"
                desc_part = descriptor[len("Moderate risk"):].strip()
                if desc_part:
                    descriptor = f"{base} — {desc_part}"
                else:
                    descriptor = random.choice(moderate_fallbacks)
            elif descriptor.lower().startswith("high risk"):
                base = "High risk"
                desc_part = descriptor[len("High risk"):].strip()
                if desc_part:
                    descriptor = f"{base} — {desc_part}"
                else:
                    descriptor = random.choice(high_fallbacks)
        
        # Final debug: ensure we have a valid descriptor
        if " — " not in descriptor or descriptor.split(" — ", 1)[1].strip() == "":
            print(f"⚠️ WARNING: Invalid descriptor format for {label}: '{descriptor}' - using fallback")
            if risk.upper() == "HIGH":
                descriptor = random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                descriptor = random.choice(moderate_fallbacks)
            else:
                descriptor = random.choice(low_fallbacks)
        
        # Ensure descriptor uniqueness - if we've already used this exact descriptor, replace it
        if descriptor in used_descriptors:
            print(f"⚠️ Duplicate descriptor detected: '{descriptor}' for {label} - replacing with unique fallback")
            # Get a unique fallback
            if risk.upper() == "HIGH":
                available = [d for d in high_fallbacks if d not in used_descriptors]
                descriptor = random.choice(available) if available else random.choice(high_fallbacks)
            elif risk.upper() == "MODERATE":
                available = [d for d in moderate_fallbacks if d not in used_descriptors]
                descriptor = random.choice(available) if available else random.choice(moderate_fallbacks)
            else:
                available = [d for d in low_fallbacks if d not in used_descriptors]
                descriptor = random.choice(available) if available else random.choice(low_fallbacks)
        
        used_descriptors.add(descriptor)
        print(f"✅ Daily insight for {label}: {descriptor}")

        daily_breakdown.append({
            "label": label,
            "insight": descriptor
        })

    # Extract preparation tip if provided
    preparation_tip = response_data.get("preparation_tip", "").strip()
    preparation_tip = _filter_app_messages(preparation_tip) or preparation_tip
    
    payload = json.dumps({
        "weekly_summary": weekly_summary,
        "daily_breakdown": daily_breakdown,
        "preparation_tip": preparation_tip if preparation_tip else None
    })

    return (payload, sources)
