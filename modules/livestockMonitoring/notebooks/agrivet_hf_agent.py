# ============================================================================
# agrivet_hf_agent.py
# AgriVet AI — Livestock Health Assistant
#
# Architecture:
#   Farmer message
#       ↓
#   Phase 1 — Vitals check     (HealthMonitor — rule-based)
#   Phase 2 — Disease detection (RF model trained on 10k cases)
#   Phase 3 — Behavioral hints  (BehavioralAnalyzer — if data available)
#   Phase 4 — Nutrition advice  (NutritionOptimizer)
#   Phase 5 — Alert generation  (AlertSystem)
#       ↓
#   LLM (HF Router) reasons over all results + llm_rules.txt constraints
#       ↓
#   Farmer-friendly response
#
# SETUP:
#   pip install requests
#   Get a FREE token at https://huggingface.co/settings/tokens
#   Create a "Fine-grained" token with permission:
#     "Make calls to Inference Providers"
#   Then run:
#     $env:HF_TOKEN="hf_..."; python agrivet_hf_agent.py
# ============================================================================

import os, sys, re, json, requests
from datetime import datetime
from typing import Dict, List, Optional, Tuple

# ── Import your 5-phase backend ───────────────────────────────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from phase1_health_monitoring  import HealthMonitor, VitalSigns, HealthStatus
    from phase2_disease_detection  import DiseaseDetector
    from phase3_behavioral_analyzer import BehavioralAnalyzer
    from phase4_nutrition_optimizer import NutritionOptimizer
    from phase5_alert_system       import AlertSystem, AlertType, AlertSeverity
    _PHASES_AVAILABLE = True
except ImportError as e:
    print(f"⚠️  Phase imports failed ({e}) — running in mock mode")
    _PHASES_AVAILABLE = False

# ── Import the RF-based disease predictor ────────────────────────────────────
try:
    from predict_disease import predict_disease as rf_predict, get_rules_for_animal
    _RF_AVAILABLE = True
except ImportError:
    print("⚠️  predict_disease.py not found — using mock predictions")
    _RF_AVAILABLE = False


# ============================================================================
# PHASE 1 — Vitals check (uses HealthMonitor from phase1)
# ============================================================================

NORMAL_RANGES = {
    "Cow":    {"body_temperature": (37.5, 39.3), "heart_rate": (40,  80),  "respiratory_rate": (10, 30)},
    "Sheep":  {"body_temperature": (38.5, 39.5), "heart_rate": (60,  120), "respiratory_rate": (12, 20)},
    "Goat":   {"body_temperature": (38.5, 40.0), "heart_rate": (70,  135), "respiratory_rate": (15, 30)},
    "Pig":    {"body_temperature": (38.5, 39.7), "heart_rate": (70,  100), "respiratory_rate": (10, 20)},
    "Dog":    {"body_temperature": (38.0, 39.2), "heart_rate": (60,  140), "respiratory_rate": (10, 35)},
    "Cat":    {"body_temperature": (38.0, 39.2), "heart_rate": (120, 180), "respiratory_rate": (20, 30)},
    "Horse":  {"body_temperature": (37.5, 38.5), "heart_rate": (28,  44),  "respiratory_rate": (8,  16)},
    "Rabbit": {"body_temperature": (38.5, 40.0), "heart_rate": (130, 325), "respiratory_rate": (30, 60)},
}


def backend_check_vitals(species: str, body_temperature: float,
                         heart_rate: float, respiratory_rate: float = None) -> dict:
    """Phase 1 — rule-based vitals check."""
    if _PHASES_AVAILABLE:
        try:
            from datetime import datetime as _dt
            monitor = HealthMonitor()
            vs = VitalSigns(
                animal_id="tmp",
                timestamp=_dt.now().isoformat(),
                body_temperature=body_temperature,
                heart_rate=int(heart_rate),
                respiratory_rate=int(respiratory_rate) if respiratory_rate else 20,
                body_condition_score=3.0,
                weight=200.0
            )
            result = monitor.check_vital_signs(vs, species=species.lower())
            status, conf = monitor.predict_health_status(vs, species=species.lower())
            return {
                "abnormalities":    result["abnormalities"],
                "overall_severity": result["overall_severity"],
                "health_status":    status.value,
                "confidence":       round(conf, 2),
            }
        except Exception as ex:
            pass  # fall through to simple check

    # Simple fallback
    ranges = NORMAL_RANGES.get(species, NORMAL_RANGES["Cow"])
    abnormalities = {}
    t_min, t_max = ranges["body_temperature"]
    if body_temperature > t_max:
        abnormalities["fever"] = {"value": body_temperature, "deviation": round(body_temperature - t_max, 2)}
    elif body_temperature < t_min:
        abnormalities["hypothermia"] = {"value": body_temperature, "deviation": round(t_min - body_temperature, 2)}
    h_min, h_max = ranges["heart_rate"]
    if heart_rate > h_max:
        abnormalities["tachycardia"] = {"value": heart_rate}
    elif heart_rate < h_min:
        abnormalities["bradycardia"] = {"value": heart_rate}
    severity = min(1.0, len(abnormalities) * 0.4)
    health_status = "Critical" if severity > 0.7 else "Poor" if severity > 0.4 else "Moderate" if abnormalities else "Good"
    return {"abnormalities": abnormalities, "overall_severity": severity, "health_status": health_status}


# ============================================================================
# PHASE 2 — Disease detection (RF model from predict_disease.py)
# ============================================================================

MOCK_DISEASES = {
    "Dog":    [("Canine Parvovirus", 0.38), ("Canine Distemper", 0.22), ("Gastroenteritis", 0.18)],
    "Cat":    [("Feline Calicivirus", 0.32), ("Panleukopenia", 0.25), ("Feline Herpesvirus", 0.18)],
    "Cow":    [("Bovine Respiratory Disease", 0.35), ("Mastitis", 0.22), ("Bovine Tuberculosis", 0.18)],
    "Horse":  [("Equine Influenza", 0.34), ("Equine Laminitis", 0.28), ("Strangles", 0.19)],
    "Sheep":  [("Bluetongue", 0.38), ("Pneumonia", 0.24), ("Scrapie", 0.20)],
    "Goat":   [("Caprine Arthritis Encephalitis", 0.40), ("Caprine Pleuropneumonia", 0.28), ("Footrot", 0.15)],
    "Pig":    [("Swine Influenza", 0.42), ("African Swine Fever", 0.30), ("Swine Erysipelas", 0.18)],
    "Rabbit": [("Myxomatosis", 0.36), ("Rabbit Hemorrhagic Disease", 0.30), ("Snuffles", 0.24)],
}


def backend_run_diagnosis(animal_type: str, symptoms: list,
                          body_temp: float = None, heart_rate: float = None,
                          binary_flags: dict = None, age: float = 3,
                          weight: float = None, duration_days: int = 7) -> dict:
    """Phase 2 — disease prediction via trained RF model."""
    if _RF_AVAILABLE:
        try:
            return rf_predict(
                animal_type=animal_type, symptoms=symptoms,
                binary_flags=binary_flags, body_temp=body_temp,
                heart_rate=heart_rate, age=age, weight=weight,
                duration_days=duration_days, top_n=3,
            )
        except Exception as ex:
            print(f"   ⚠️ RF predict failed: {ex}")

    # Mock fallback
    diseases = MOCK_DISEASES.get(animal_type.capitalize(), MOCK_DISEASES["Dog"])
    return {
        "animal": animal_type,
        "top_predictions": [{"disease": d, "probability": p} for d, p in diseases],
        "note": "Mock predictions — rf_model_final.pkl not found",
    }


# ============================================================================
# PHASE 4 — Nutrition optimizer
# ============================================================================

def backend_get_nutrition(species: str, weight: float, stage: str = "maintenance") -> dict:
    """Phase 4 — diet recommendation."""
    if _PHASES_AVAILABLE:
        try:
            optimizer = NutritionOptimizer()
            return optimizer.recommend_diet({
                "species": species.lower(), "weight": weight,
                "stage": stage, "milk_production_liters": 0
            })
        except Exception:
            pass

    daily = {"Dog": 0.5, "Cat": 0.25, "Cow": 12, "Horse": 10,
             "Sheep": 2, "Goat": 1.5, "Pig": 3, "Rabbit": 0.2}.get(species, 5)
    return {
        "daily_feed_kg": round(daily * (weight / 100), 1),
        "schedule": [
            {"time": "06:00", "meal": "Morning",  "amount_kg": round(daily * 0.35, 2)},
            {"time": "12:00", "meal": "Midday",   "amount_kg": round(daily * 0.30, 2)},
            {"time": "18:00", "meal": "Evening",  "amount_kg": round(daily * 0.35, 2)},
        ]
    }


# ============================================================================
# PHASE 5 — Alert system
# ============================================================================

def backend_generate_alert(animal_id: str, alert_type: str,
                           severity: str, message: str) -> dict:
    """Phase 5 — generate and log an alert."""
    if _PHASES_AVAILABLE:
        try:
            alert_sys = AlertSystem()
            atype = getattr(AlertType,
                            alert_type.upper().replace(" ", "_"),
                            AlertType.HEALTH_WARNING)
            asev  = getattr(AlertSeverity,
                            severity.upper(),
                            AlertSeverity.MEDIUM)
            alert = alert_sys.generate_alert(atype, asev, animal_id, message, {})
            return alert.to_dict()
        except Exception:
            pass

    return {
        "alert_id":  f"ALT-{datetime.now().timestamp():.0f}",
        "type":      alert_type,
        "severity":  severity,
        "message":   message,
        "timestamp": datetime.now().isoformat(),
        "acknowledged": False,
    }


# ============================================================================
# CONVERSATION STATE
# ============================================================================

class ConversationState:
    def __init__(self, animal_id: str):
        self.animal_id        = animal_id
        self.collected        : Dict  = {}
        self.phase1_result    : Optional[Dict] = None
        self.phase2_result    : Optional[Dict] = None
        self.phase4_result    : Optional[Dict] = None
        self.active_alerts    : List[Dict]     = []
        self.turn_count       : int  = 0

    def to_context_block(self) -> str:
        lines = [f"[SESSION animal_id={self.animal_id} turn={self.turn_count}]"]
        if self.collected:
            lines.append("Collected so far: " + json.dumps(self.collected))
        if self.phase1_result:
            abn  = list(self.phase1_result.get("abnormalities", {}).keys())
            stat = self.phase1_result.get("health_status", "unknown")
            lines.append(f"Phase 1 vitals: status={stat}, abnormalities={abn or 'none'}")
        if self.phase2_result:
            top  = self.phase2_result.get("top_predictions", [])[:3]
            preds = ", ".join(f"{p['disease']} ({p['probability']*100:.0f}%)" for p in top)
            lines.append(f"Phase 2 RF diagnosis: {preds}")
        if self.phase4_result:
            lines.append(f"Phase 4 nutrition: daily feed {self.phase4_result.get('daily_feed_kg','?')} kg")
        if self.active_alerts:
            lines.append(f"Active alerts: {len(self.active_alerts)}")
        return "\n".join(lines)


# ============================================================================
# TOOL DEFINITIONS (described in plain text — HF models don't support JSON tools)
# ============================================================================

TOOL_DESCRIPTIONS = """
You have access to four backend tools. Call them by writing a JSON block
between <tool_call> and </tool_call> tags. Only ONE tool call per reply.

TOOL 1 — check_vitals  (Phase 1)
  When: farmer gives numeric temperature, heart rate, or respiratory rate.
  JSON: {"tool":"check_vitals","species":"Cow","body_temperature":40.1,
         "heart_rate":90,"respiratory_rate":35}

TOOL 2 — run_diagnosis  (Phase 2 — RF model)
  When: you know the animal type AND at least one symptom.
  JSON: {"tool":"run_diagnosis","animal_type":"Cow",
         "symptoms":["fever","coughing"],
         "binary_flags":{"Coughing":1,"Appetite_Loss":1},
         "body_temp":40.1,"heart_rate":90,"duration_days":5}

TOOL 3 — get_nutrition  (Phase 4)
  When: farmer asks about feeding, or animal is underweight.
  JSON: {"tool":"get_nutrition","species":"Cow","weight":450,"stage":"maintenance"}
  (stage options: maintenance, growing, lactating)

TOOL 4 — generate_alert  (Phase 5)
  When: health status is Poor or Critical, or disease probability > 70%.
  JSON: {"tool":"generate_alert","animal_id":"COW-001",
         "alert_type":"HEALTH_WARNING","severity":"HIGH",
         "message":"Fever + coughing detected"}

After a TOOL_RESULT block, interpret it conversationally. Never show raw JSON.
"""


# ============================================================================
# SYSTEM PROMPT
# ============================================================================

SYSTEM_PROMPT_TEMPLATE = """You are AgriVet AI, a livestock health assistant built for farmers.

=== IDENTITY ===
- Detect the farmer's language in their first message and always reply in that language.
  Supported: English, French, Tunisian Arabic (Darija), or mixed French/Darija.
- Be warm, practical, and direct. Farmers need actions, not long reports.

=== 5-PHASE WORKFLOW ===
For each animal problem, work through these phases in order:
  Phase 1 — Check vitals (temperature, heart rate) if numbers are given → use check_vitals
  Phase 2 — Run disease diagnosis from symptoms → use run_diagnosis
  Phase 3 — Note any behavioral signs the farmer mentions (lameness, isolation, appetite)
  Phase 4 — Offer nutrition advice if relevant → use get_nutrition
  Phase 5 — Trigger an alert if status is Poor/Critical → use generate_alert

=== CONVERSATION RULES ===
- Ask ONE question at a time. Never send a list of questions.
- Once you have animal type + one symptom, call run_diagnosis immediately.
- After getting tool results, respond in plain language — never paste raw JSON.

=== RESPONSE FORMAT AFTER DIAGNOSIS ===
1. Risk emoji: 🔴 Critical  |  🟡 Moderate  |  🟢 Low
2. Most likely disease + confidence level in plain words
3. 3–5 numbered immediate actions
4. One follow-up question

=== SAFETY RULES ===
- You are NOT a replacement for a veterinarian. Say this when risk is High/Critical.
- If risk is Critical → always start with "🔴 URGENT — Contact a vet NOW".
- Keep each reply under 200 words.
- Never invent drug dosages or surgical procedures.

=== CLINICAL RULES FROM TRAINING DATA ===
{animal_rules}

=== CURRENT SESSION STATE ===
{state_context}

=== TOOL ACCESS ===
{tool_descriptions}
"""


# ============================================================================
# HF ROUTER API (new endpoint active since July 2025)
# ============================================================================

HF_MODEL   = "meta-llama/Llama-3.1-8B-Instruct"
HF_API_URL = "https://router.huggingface.co/v1/chat/completions"


def hf_chat(system_prompt: str, conversation: List[Dict], hf_token: str) -> str:
    headers = {
        "Authorization": f"Bearer {hf_token}",
        "Content-Type":  "application/json",
    }
    messages = [{"role": "system", "content": system_prompt}] + conversation
    payload  = {
        "model":       HF_MODEL,
        "messages":    messages,
        "max_tokens":  512,
        "temperature": 0.4,
        "top_p":       0.9,
    }
    try:
        resp = requests.post(HF_API_URL, headers=headers, json=payload, timeout=60)
        resp.raise_for_status()
        data = resp.json()
        if "choices" in data:
            return data["choices"][0]["message"]["content"].strip()
        return f"[Unexpected API response: {data}]"
    except requests.exceptions.Timeout:
        return "⏳ Model loading... try again in a few seconds."
    except requests.exceptions.HTTPError as e:
        status = resp.status_code
        if status == 503:
            return "⏳ Model warming up. Try again in 30s."
        if status == 401:
            return ("❌ Token invalid or missing permission.\n"
                    "   Go to https://huggingface.co/settings/tokens\n"
                    "   Create a Fine-grained token with 'Make calls to Inference Providers' permission.")
        if status == 402:
            return "❌ Monthly free quota exceeded. Try model 'Qwen/Qwen2.5-7B-Instruct' instead."
        return f"[API error {status}: {e}]"
    except Exception as e:
        return f"[Connection error: {e}]"


# ============================================================================
# TOOL PARSER & EXECUTOR
# ============================================================================

def extract_tool_call(text: str) -> Optional[Dict]:
    match = re.search(r"<tool_call>(.*?)</tool_call>", text, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(1).strip())
    except json.JSONDecodeError:
        return None


def execute_tool(tool_call: Dict, state: ConversationState) -> Tuple[str, dict]:
    tool = tool_call.get("tool", "")

    if tool == "check_vitals":
        species  = tool_call.get("species", state.collected.get("animal_type", "Cow"))
        temp     = float(tool_call.get("body_temperature", 39.0))
        hr       = float(tool_call.get("heart_rate", 70))
        rr       = tool_call.get("respiratory_rate")
        state.collected.update({"species": species, "body_temperature": temp, "heart_rate": hr})
        result = backend_check_vitals(species, temp, hr, float(rr) if rr else None)
        state.phase1_result = result
        # Auto-trigger alert if critical
        if result.get("health_status") in ("Critical", "Poor"):
            alert = backend_generate_alert(
                state.animal_id, "HEALTH_WARNING",
                "CRITICAL" if result["health_status"] == "Critical" else "HIGH",
                f"Vitals alert: {result['health_status']}"
            )
            state.active_alerts.append(alert)
        return "check_vitals", result

    elif tool == "run_diagnosis":
        animal   = tool_call.get("animal_type", state.collected.get("animal_type", "Cow"))
        symptoms = tool_call.get("symptoms", [])
        flags    = tool_call.get("binary_flags", {})
        temp     = tool_call.get("body_temp")
        hr       = tool_call.get("heart_rate")
        dur      = int(tool_call.get("duration_days", 7))
        state.collected.update({"animal_type": animal, "symptoms": symptoms})
        result = backend_run_diagnosis(animal, symptoms, body_temp=temp,
                                       heart_rate=hr, binary_flags=flags,
                                       duration_days=dur)
        state.phase2_result = result
        # Auto-alert if top disease > 70%
        top = result.get("top_predictions", [])
        if top and top[0]["probability"] > 0.70:
            alert = backend_generate_alert(
                state.animal_id, "DISEASE_ALERT", "HIGH",
                f"High probability disease: {top[0]['disease']} ({top[0]['probability']*100:.0f}%)"
            )
            state.active_alerts.append(alert)
        return "run_diagnosis", result

    elif tool == "get_nutrition":
        species = tool_call.get("species", state.collected.get("animal_type", "Cow"))
        weight  = float(tool_call.get("weight", 400))
        stage   = tool_call.get("stage", "maintenance")
        result  = backend_get_nutrition(species, weight, stage)
        state.phase4_result = result
        return "get_nutrition", result

    elif tool == "generate_alert":
        result = backend_generate_alert(
            tool_call.get("animal_id", state.animal_id),
            tool_call.get("alert_type", "HEALTH_WARNING"),
            tool_call.get("severity", "MEDIUM"),
            tool_call.get("message", "Alert generated")
        )
        state.active_alerts.append(result)
        return "generate_alert", result

    return "unknown", {"error": f"Unknown tool: {tool}"}


# ============================================================================
# AGENT TURN
# ============================================================================

def build_system_prompt(state: ConversationState) -> str:
    animal_type = state.collected.get("animal_type", "")
    if animal_type and _RF_AVAILABLE:
        try:
            animal_rules = get_rules_for_animal(animal_type.capitalize())
        except Exception:
            animal_rules = "(Rules not available)"
    else:
        animal_rules = "(Will load once animal type is known)"

    return SYSTEM_PROMPT_TEMPLATE.format(
        animal_rules=animal_rules,
        state_context=state.to_context_block(),
        tool_descriptions=TOOL_DESCRIPTIONS,
    )


def run_agent_turn(hf_token: str, conversation: List[Dict],
                   state: ConversationState, max_tool_rounds: int = 3) -> str:
    system = build_system_prompt(state)

    for _ in range(max_tool_rounds):
        raw = hf_chat(system, conversation, hf_token)

        tool_call = extract_tool_call(raw)
        if not tool_call:
            return re.sub(r"<tool_call>.*?</tool_call>", "", raw, flags=re.DOTALL).strip()

        tool_name, tool_result = execute_tool(tool_call, state)
        print(f"   🔧  [{tool_name}] — Phase backend executed")

        clean = re.sub(r"<tool_call>.*?</tool_call>", "", raw, flags=re.DOTALL).strip()
        tool_result_msg = (
            f"TOOL_RESULT [{tool_name}]:\n{json.dumps(tool_result, indent=2)}\n\n"
            "Now interpret this result for the farmer following the response format rules. "
            "Do not show raw JSON."
        )
        if clean:
            conversation.append({"role": "assistant", "content": clean})
        conversation.append({"role": "user", "content": tool_result_msg})

        system = build_system_prompt(state)

    return hf_chat(system, conversation, hf_token)


# ============================================================================
# TERMINAL INTERFACE
# ============================================================================

def main():
    hf_token = os.environ.get("HF_TOKEN", "")
    if not hf_token:
        print("\n❌  HF_TOKEN not set.")
        print("   1. Go to https://huggingface.co/settings/tokens")
        print("   2. Create Fine-grained token with 'Make calls to Inference Providers'")
        print("   3. Run:  $env:HF_TOKEN=\"hf_...\"  (PowerShell)")
        raise SystemExit(1)

    animal_id    = f"ANIMAL-{datetime.now().strftime('%H%M%S')}"
    state        = ConversationState(animal_id)
    conversation : List[Dict] = []

    phase_status = "✅" if _PHASES_AVAILABLE else "⚠️ mock"
    rf_status    = "✅" if _RF_AVAILABLE    else "⚠️ mock"

    print("\n" + "═"*62)
    print("   🐄  AgriVet AI  —  Livestock Health Assistant")
    print(f"   Model  : {HF_MODEL}")
    print(f"   Phases : {phase_status}   RF model: {rf_status}")
    print("═"*62)
    print("   Speak in any language. Type 'quit' to exit.")
    print("   ⏳ First response may take ~30s (cold start)\n")

    conversation.append({
        "role": "user",
        "content": "Hello — greet me warmly and ask what animal I need help with today."
    })
    opening = run_agent_turn(hf_token, conversation, state)
    conversation.append({"role": "assistant", "content": opening})
    print(f"AgriVet AI:  {opening}\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nAgriVet AI: Take care of your animals! 🌿\n")
            break

        if not user_input:
            continue
        if user_input.lower() in {"quit","exit","bye","sortir","7abi","bslama"}:
            print("\nAgriVet AI: Take care of your animals! 🌿\n")
            break

        conversation.append({"role": "user", "content": user_input})
        state.turn_count += 1

        print("   ⏳ thinking...", end="\r")
        reply = run_agent_turn(hf_token, conversation, state)
        conversation.append({"role": "assistant", "content": reply})
        print(f"AgriVet AI:  {reply}\n")

        # Show phase summary after each turn
        if state.phase1_result or state.phase2_result:
            print("   ─── Phase Summary ───────────────────────────────────")
            if state.phase1_result:
                stat = state.phase1_result.get("health_status","?")
                abn  = list(state.phase1_result.get("abnormalities",{}).keys())
                print(f"   Phase 1: {stat}  {abn or '(no abnormalities)'}")
            if state.phase2_result:
                top = state.phase2_result.get("top_predictions",[])[:2]
                for p in top:
                    print(f"   Phase 2: {p['disease']} — {p['probability']*100:.0f}%")
            if state.active_alerts:
                print(f"   Phase 5: {len(state.active_alerts)} alert(s) generated")
            print()


if __name__ == "__main__":
    main()