# routers/ai_query.py
from fastapi import APIRouter, Depends
from core.security import get_current_user
from models.schemas import AIQueryRequest, AIQueryResponse

router = APIRouter(prefix="/ai", tags=["AI Assistant"])

# ── Local knowledge base (RAG-style cached data) ──────────────────────────────
CRISIS_KB = {
    "shelters": [
        {"name": "Nehru Indoor Stadium", "address": "ICF, Chennai", "capacity": 2000, "lat": 13.0844, "lng": 80.2717},
        {"name": "YMCA Grounds Nandanam", "address": "Nandanam, Chennai", "capacity": 500, "lat": 13.0274, "lng": 80.2337},
        {"name": "DRJ Convention Centre", "address": "Teynampet, Chennai", "lat": 13.0765, "lng": 80.2620},
    ],
    "hospitals": [
        {"name": "Rajiv Gandhi Govt. Hospital", "phone": "044-25305000", "address": "Park Town, Chennai"},
        {"name": "Government Stanley Hospital", "phone": "044-25281361", "address": "Old Jail Road, Chennai"},
        {"name": "Apollo Hospitals", "phone": "1860-500-1066", "address": "Greams Road, Chennai"},
        {"name": "MIOT International", "phone": "044-22492288", "address": "Manapakkam, Chennai"},
    ],
    "helplines": {
        "police": "100",
        "ambulance": "108",
        "fire": "101",
        "women": "1091",
        "disaster": "1078",
        "child": "1098",
        "coast_guard": "1554",
        "national_emergency": "112",
        "ndrf": "011-24363260",
        "imd": "044-28131000",
    },
    "flood_guidelines": [
        "Move to highest ground immediately — do not wait",
        "Avoid walking or driving through moving water",
        "Stay away from drains, channels, and streams",
        "Disconnect all electrical appliances",
        "Store 3 days of clean drinking water",
        "Call NDRF at 011-24363260 for rescue",
    ],
    "earthquake_guidelines": [
        "DROP to hands and knees immediately",
        "Take COVER under a sturdy desk or table",
        "HOLD ON until shaking stops",
        "Stay away from windows, heavy furniture, exterior walls",
        "Do NOT run outside during shaking",
        "Expect aftershocks — stay prepared",
    ],
    "cyclone_guidelines": [
        "Stay indoors in the strongest part of the building",
        "Close all windows, doors, and board up if possible",
        "Store food, water, and medicines for 3 days",
        "Charge all devices and power banks now",
        "Avoid candles — use battery-powered torches",
        "After the eye passes, the storm is NOT over",
    ],
}


def _build_answer(query: str) -> tuple[str, list[str]]:
    """
    Basic keyword-based RAG: match query to knowledge base entries.
    Returns (answer_text, sources).
    In production, replace with embedding similarity + LLM generation.
    """
    q = query.lower()

    # Shelter queries
    if any(k in q for k in ["shelter", "safe place", "where to go", "refuge", "stay"]):
        shelters = CRISIS_KB["shelters"]
        answer = "Nearest available shelters in Chennai:\n\n"
        for i, s in enumerate(shelters, 1):
            answer += f"{i}. **{s['name']}**\n   📍 {s['address']}"
            if "capacity" in s:
                answer += f"\n   👥 Capacity: {s['capacity']}"
            answer += "\n\n"
        answer += "Tap the Map tab to navigate to any shelter."
        return answer, ["Crisis Response Location Database"]

    # Hospital / medical queries
    if any(k in q for k in ["hospital", "medical", "doctor", "ambulance", "injury", "hurt", "sick"]):
        hospitals = CRISIS_KB["hospitals"]
        answer = "Nearest hospitals and medical facilities:\n\n"
        for i, h in enumerate(hospitals, 1):
            answer += f"{i}. **{h['name']}**\n   📞 {h['phone']}\n   📍 {h['address']}\n\n"
        answer += "For immediate medical emergencies, call **108** (free ambulance service)."
        return answer, ["Crisis Response Medical Database"]

    # Emergency contact queries
    if any(k in q for k in ["contact", "number", "call", "helpline", "phone"]):
        hl = CRISIS_KB["helplines"]
        answer = (
            "Key emergency numbers:\n\n"
            f"🚔 Police: {hl['police']}\n"
            f"🚑 Ambulance: {hl['ambulance']}\n"
            f"🚒 Fire: {hl['fire']}\n"
            f"👩 Women's Helpline: {hl['women']}\n"
            f"🆘 Disaster Management: {hl['disaster']}\n"
            f"🧒 Child Helpline: {hl['child']}\n"
            f"⚓ Coast Guard: {hl['coast_guard']}\n"
            f"🌏 National Emergency: {hl['national_emergency']}\n"
            f"🪖 NDRF: {hl['ndrf']}\n"
            f"🌦️ IMD (Weather): {hl['imd']}"
        )
        return answer, ["Govt. Emergency Services Directory"]

    # Flood queries
    if any(k in q for k in ["flood", "water level", "inundation", "drowning", "flooded"]):
        guidelines = CRISIS_KB["flood_guidelines"]
        answer = "Flood safety guidelines:\n\n"
        answer += "\n".join(f"• {g}" for g in guidelines)
        answer += "\n\nFor boat rescue, use the **Request Help** button in this app."
        return answer, ["NDMA Flood Guidelines", "NDRF Protocol"]

    # Earthquake queries
    if any(k in q for k in ["earthquake", "tremor", "seismic", "aftershock"]):
        guidelines = CRISIS_KB["earthquake_guidelines"]
        answer = "Earthquake safety — DROP, COVER, HOLD ON:\n\n"
        answer += "\n".join(f"• {g}" for g in guidelines)
        return answer, ["NDMA Earthquake Guidelines"]

    # Cyclone queries
    if any(k in q for k in ["cyclone", "storm", "hurricane", "typhoon", "wind"]):
        guidelines = CRISIS_KB["cyclone_guidelines"]
        answer = "Cyclone preparedness:\n\n"
        answer += "\n".join(f"• {g}" for g in guidelines)
        answer += "\n\nMonitor real-time updates from IMD at mausam.imd.gov.in"
        return answer, ["IMD Cyclone Guidelines", "NDMA Protocol"]

    # Food / water / resource queries
    if any(k in q for k in ["food", "water", "resource", "supply", "relief camp"]):
        answer = (
            "To request emergency resources:\n\n"
            "1. Tap **Request Help** on the Home screen\n"
            "2. Select: Food / Water / Shelter / Medical\n"
            "3. Your GPS location is auto-attached\n"
            "4. Submit — our team responds within 30 minutes\n\n"
            "Active relief camps:\n"
            "• Kilpauk Medical College Grounds\n"
            "• Corporation School, Adyar\n"
            "• Rajaji Hall, Triplicane"
        )
        return answer, ["Crisis Response Relief Network"]

    # Rescue queries
    if any(k in q for k in ["rescue", "trapped", "stuck", "stranded", "boat", "helicopter"]):
        answer = (
            "Emergency rescue options:\n\n"
            "🚤 **Boat Rescue**: Use the Request Help button → select Boat Rescue\n"
            "🚁 **Helicopter**: For life-threatening situations → Helicopter Rescue\n"
            "📞 **NDRF Hotline**: 011-24363260\n"
            "📞 **Coast Guard**: 1554\n\n"
            "When requesting rescue:\n"
            "• Keep your phone charged\n"
            "• Stay in a visible location\n"
            "• Signal with a torch or bright cloth"
        )
        return answer, ["NDRF Rescue Protocol", "Coast Guard Guidelines"]

    # Default response
    answer = (
        "I'm your Crisis Response AI assistant. I can help you with:\n\n"
        "• 🏠 **Nearest shelters** — ask 'Where is the nearest shelter?'\n"
        "• 🏥 **Hospitals & medical** — ask 'Find nearest hospital'\n"
        "• 📞 **Emergency numbers** — ask 'Emergency contact numbers'\n"
        "• 🌊 **Flood safety** — ask 'Flood safety tips'\n"
        "• 🌀 **Cyclone prep** — ask 'Cyclone guidelines'\n"
        "• 🍲 **Request resources** — ask 'How to request food and water'\n"
        "• 🚤 **Rescue** — ask 'How to request rescue'\n\n"
        "What do you need help with right now?"
    )
    return answer, ["Crisis Response AI"]


# ── AI query endpoint ─────────────────────────────────────────────────────────
@router.post("/query", response_model=AIQueryResponse)
async def ai_query(
    payload: AIQueryRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Process a natural language query using local RAG.
    Keywords are matched against the cached crisis knowledge base.
    In production, connect to an LLM API for generative responses.
    """
    answer, sources = _build_answer(payload.query)
    return AIQueryResponse(
        query=payload.query,
        answer=answer,
        sources=sources,
        confidence=0.92,
    )
