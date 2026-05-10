import os, json, math, joblib, requests, urllib.request
from datetime import datetime
import numpy as np
import torch
import torch.nn as nn
import gradio as gr
from fastapi import Request
from fastapi.responses import JSONResponse

# ── Config ────────────────────────────────────────────────────────────────────
if os.path.exists("agrismart_agent_config.json"):
    with open("agrismart_agent_config.json") as f:
        CONFIG = json.load(f)
    ACTIONS = CONFIG["actions_mm"]
    SM_LOW  = CONFIG["sm_optimal_band"][0]
    SM_HIGH = CONFIG["sm_optimal_band"][1]
else:
    ACTIONS = [0, 5, 10, 15, 20]
    SM_LOW  = 0.208
    SM_HIGH = 0.28

STATE_DIM  = 9
ACTION_DIM = len(ACTIONS)

# ── Architecture DQN générique (reconstruit depuis les formes du state_dict) ──
class DQNNet(nn.Module):
    def __init__(self, state_dim, action_dim, hidden_sizes):
        super().__init__()
        layers = []
        prev = state_dim
        for h in hidden_sizes:
            layers += [nn.Linear(prev, h), nn.ReLU()]
            prev = h
        layers.append(nn.Linear(prev, action_dim))
        self.net = nn.Sequential(*layers)
    def forward(self, x):
        return self.net(x)

# ── Téléchargement des modèles depuis GitHub ──────────────────────────────────
GITHUB = "https://raw.githubusercontent.com/Hajer5503/Esprit-PI-4DS5-AgriSmart/hajer-branch/modules/irrigation_rl/models"

def dl(name):
    os.makedirs("models", exist_ok=True)
    path = f"models/{name}"
    if not os.path.exists(path):
        print(f"⬇️  Downloading {name} ...")
        urllib.request.urlretrieve(f"{GITHUB}/{name}", path)
        print(f"✅ {name} OK")
    return path

def _infer_from_state_dict(sd, filename):
    """
    Reconstruit un DQNNet depuis un state_dict en remappant les clés par position.
    Gère n'importe quelle convention de nommage (fc1/fc2, net.0/net.2, layers.0…).
    """
    # Keys in registration order = forward-pass order
    weight_keys = [k for k in sd.keys() if k.endswith('.weight')]
    all_keys    = list(sd.keys())
    print(f"📋 {filename}: {[(k, tuple(sd[k].shape)) for k in weight_keys]}")

    if len(weight_keys) < 2:
        print(f"⚠️  {filename}: pas assez de couches linéaires")
        return None, STATE_DIM

    state_dim    = int(sd[weight_keys[0]].shape[1])
    action_dim   = int(sd[weight_keys[-1]].shape[0])
    hidden_sizes = [int(sd[k].shape[0]) for k in weight_keys[:-1]]
    print(f"🔍 {filename}: state={state_dim}, hidden={hidden_sizes}, actions={action_dim}")

    net = DQNNet(state_dim, action_dim, hidden_sizes)
    tgt_keys = list(net.state_dict().keys())

    if len(all_keys) != len(tgt_keys):
        print(f"⚠️  {filename}: {len(all_keys)} clés source ≠ {len(tgt_keys)} cibles")
        return None, state_dim

    # Remap par position — indépendant du nom des clés
    for tk, sk in zip(tgt_keys, all_keys):
        if sd[sk].shape != net.state_dict()[tk].shape:
            print(f"⚠️  {filename}: forme incompatible {sk}{tuple(sd[sk].shape)} → {tk}{tuple(net.state_dict()[tk].shape)}")
            return None, state_dim

    net.load_state_dict({tk: sd[sk] for tk, sk in zip(tgt_keys, all_keys)})
    net.eval()
    arch = '×'.join(str(h) for h in hidden_sizes)
    print(f"✅ {filename} chargé (state={state_dim}→[{arch}]→{action_dim})")
    return net, state_dim


def load_dqn(filename):
    """Charge un modèle DQN PyTorch — gère full model, state_dict, et checkpoint dict."""
    path = dl(filename)
    try:
        obj = torch.load(path, map_location="cpu", weights_only=False)

        # Cas 1 : modèle complet (torch.save(model, path))
        if isinstance(obj, nn.Module):
            obj.eval()
            state_dim = STATE_DIM
            for m in obj.modules():
                if isinstance(m, nn.Linear):
                    state_dim = m.in_features
                    break
            print(f"✅ {filename} chargé (full model, state_dim={state_dim})")
            return obj, state_dim

        # Cas 2 : checkpoint dict  {'model_state_dict': ..., 'epoch': ...}
        if isinstance(obj, dict):
            sd = (obj.get('model_state_dict') or obj.get('state_dict')
                  or obj.get('model') or obj)
            return _infer_from_state_dict(sd, filename)

        print(f"⚠️  {filename}: type inconnu {type(obj)}")
        return None, STATE_DIM

    except Exception as e:
        print(f"❌ {filename} : {e}")
        return None, STATE_DIM

# ── Chargement des modèles Layer 1 (sklearn) ─────────────────────────────────
sm_model  = joblib.load(dl("layer1_model_sm_root.pkl"))
et0_model = joblib.load(dl("layer1_model_et0.pkl"))

with open(dl("layer1_feature_cols.json"))     as f: SM_FEATURES  = json.load(f)
with open(dl("layer1_et0_feature_cols.json")) as f: ET0_FEATURES = json.load(f)

# ── Chargement des modèles Layer 2 (PyTorch DQN) ─────────────────────────────
_dqn_best,      _sdim_best      = load_dqn("layer2_dqn_pytorch_best.pt")
_dqn_augmented, _sdim_augmented = load_dqn("layer2_dqn_agent_augmented.pt")
# Liste de (modèle, state_dim_attendu)
dqn_models = [(m, s) for m, s in [(_dqn_best, _sdim_best), (_dqn_augmented, _sdim_augmented)] if m is not None]

print(f"🧠 DQN models: {len(dqn_models)}/2 chargés")
print(f"🌱 Layer1 — SM features: {len(SM_FEATURES)}, ET0 features: {len(ET0_FEATURES)}")

# ── Constantes FAO-56 ─────────────────────────────────────────────────────────
FC = 0.28
WP = 0.12

CITIES = {
    "Tunis":    (36.81, 10.18), "Sfax":    (34.74, 10.76),
    "Sousse":   (35.83, 10.64), "Nabeul":  (36.45, 10.73),
    "Gabes":    (33.88, 10.00), "Bizerte": (37.27,  9.87),
    "Kairouan": (35.67, 10.10), "Gafsa":   (34.42,  8.78),
}

# ── Step 1 : Météo Open-Meteo ─────────────────────────────────────────────────
def get_weather(location: str = "Tunis") -> dict:
    lat, lon = CITIES.get(location, (36.81, 10.18))
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            f"&daily=precipitation_sum,temperature_2m_max,temperature_2m_min,"
            f"et0_fao_evapotranspiration,wind_speed_10m_max,relative_humidity_2m_max"
            f"&forecast_days=2&timezone=Africa%2FTunis"
        )
        d = requests.get(url, timeout=10).json()["daily"]
        precip = float(d["precipitation_sum"][1] or 0.0)
        tmax   = float(d["temperature_2m_max"][1] or 28.0)
        tmin   = float(d["temperature_2m_min"][1] or 15.0)
        et0    = float(d["et0_fao_evapotranspiration"][1] or 3.5)
        wind   = float(d.get("wind_speed_10m_max",       [0, 10])[1] or 10.0)
        rh     = float(d.get("relative_humidity_2m_max", [0, 60])[1] or 60.0)
        return {"precipitation_mm": precip, "temp_max_c": tmax, "temp_min_c": tmin,
                "et0_forecast_mm": et0, "wind_kmh": wind, "rh_pct": rh,
                "rain_risk": precip > 2.0}
    except Exception as e:
        return {"precipitation_mm": 0.0, "temp_max_c": 28.0, "temp_min_c": 15.0,
                "et0_forecast_mm": 3.5, "wind_kmh": 10.0, "rh_pct": 60.0,
                "rain_risk": False, "error": str(e)}

# ── Helpers agronomiques ──────────────────────────────────────────────────────
def hargreaves_et0(tmax, tmin, ra_mj=18.0):
    tmean = (tmax + tmin) / 2.0
    return 0.0023 * (tmean + 17.8) * math.sqrt(abs(tmax - tmin)) * ra_mj * 0.408

def vpd(temp_c, rh_pct):
    es = 0.6108 * math.exp(17.27 * temp_c / (temp_c + 237.3))
    return max(0.0, es * (1 - rh_pct / 100.0))

def doy_features(date_str):
    dt  = datetime.strptime(date_str, "%Y-%m-%d")
    doy = dt.timetuple().tm_yday
    return math.sin(2 * math.pi * doy / 365), math.cos(2 * math.pi * doy / 365), doy

# ── Step 2 : Layer 1 — prédiction SM & ET0 demain ────────────────────────────
def layer1_forecast(sensor: dict) -> dict:
    date_str = sensor.get("date", datetime.now().strftime("%Y-%m-%d"))
    sin_doy, cos_doy, doy = doy_features(date_str)

    temp_c  = sensor.get("temp_c",   22.0)
    rh_pct  = sensor.get("rh_pct",   60.0)
    wind    = sensor.get("wind_kmh", 10.0)
    tmax    = temp_c + 4.0
    tmin    = temp_c - 4.0

    et0_calc   = hargreaves_et0(tmax, tmin)
    et0_in     = sensor.get("et0_mm", et0_calc)
    vpd_val    = vpd(temp_c, rh_pct)
    kc         = sensor.get("kc", 0.85)
    precip     = sensor.get("precip_mm", 0.0)
    irrig      = sensor.get("irrigation_mm", 0.0)
    sm_root    = sensor.get("sm_root", 0.25)
    sm_shallow = sensor.get("sm_shallow", sm_root - 0.01)
    sm_deep    = sensor.get("sm_deep",    sm_root + 0.02)
    dos        = sensor.get("day_of_season", 45)

    base = {
        "et0_mm": et0_in, "precip_mm": precip, "temp_c": temp_c, "rh_pct": rh_pct,
        "wind_kmh": wind, "sm_root": sm_root, "sm_shallow": sm_shallow,
        "sm_deep": sm_deep, "kc": kc, "irrigation_mm": irrig, "vpd": vpd_val,
        "sin_doy": sin_doy, "cos_doy": cos_doy, "doy": doy,
        "month": datetime.strptime(date_str, "%Y-%m-%d").month,
        "day_of_season": dos, "etc_mm": sensor.get("etc_mm", et0_in * kc),
        "sm_root_lag1": sm_root, "sm_shallow_lag1": sm_shallow, "sm_deep_lag1": sm_deep,
        "et0_lag1": et0_in, "precip_lag1": precip, "irrig_lag1": irrig,
        "sm_root_lag2": sm_root, "sm_shallow_lag2": sm_shallow,
        "et0_lag2": et0_in, "precip_lag2": 0.0, "irrig_lag2": 0.0,
        "sm_root_roll3": sm_root, "et0_roll3": et0_in, "precip_roll3": precip,
    }

    try:
        sm_vec   = np.array([[base.get(f, 0.0) for f in SM_FEATURES]],  dtype=np.float32)
        pred_sm  = float(np.clip(sm_model.predict(sm_vec)[0], WP, FC))
        e0_vec   = np.array([[base.get(f, 0.0) for f in ET0_FEATURES]], dtype=np.float32)
        pred_et0 = float(max(0.0, et0_model.predict(e0_vec)[0]))
    except Exception as ex:
        pred_sm  = float(np.clip(sm_root + (irrig + precip) / 200 - et0_in * kc / 100, WP, FC))
        pred_et0 = et0_in
        print(f"Layer1 fallback ({ex})")

    stress = ("critique" if pred_sm < 0.15 else
              "modéré"   if pred_sm < SM_LOW  else
              "normal"   if pred_sm < SM_HIGH else "surplus")
    return {"pred_sm_root": pred_sm, "pred_et0_mm": pred_et0,
            "stress_level": stress, "stress_gap": round(max(0.0, SM_LOW - pred_sm), 4)}

# ── Step 3 : Layer 2 — DQN irrigation advisor (PyTorch ensemble) ──────────────
def _make_state(sensor: dict, pred_sm: float, pred_et0: float, target_dim: int) -> torch.Tensor:
    """Construit le vecteur d'état et l'adapte à la dimension attendue par le modèle."""
    base = [
        sensor.get("et0_mm",        3.0),
        sensor.get("precip_mm",     0.0),
        sensor.get("sm_shallow",    sensor.get("sm_root", 0.25)),
        sensor.get("sm_deep",       sensor.get("sm_root", 0.25) + 0.02),
        sensor.get("kc",            0.85),
        sensor.get("growth_stage",  1) / 4.0,
        sensor.get("day_of_season", 45) / 228.0,
        pred_sm,
        min(pred_et0 / 10.0, 1.0),
    ]
    if target_dim <= len(base):
        vec = base[:target_dim]
    else:
        vec = base + [0.0] * (target_dim - len(base))
    return torch.tensor(vec, dtype=torch.float32).unsqueeze(0)


def rl_advisor(sensor: dict, pred_sm: float, pred_et0: float) -> dict:
    action_idx = None
    if dqn_models:
        try:
            with torch.no_grad():
                q_arrays = []
                for model, sdim in dqn_models:
                    state_t = _make_state(sensor, pred_sm, pred_et0, sdim)
                    q_arrays.append(model(state_t).numpy()[0])
            q_avg = np.mean(q_arrays, axis=0)
            action_idx = int(np.argmax(q_avg))
            print(f"DQN Q={np.round(q_avg, 3)} → action {action_idx} ({ACTIONS[action_idx]} mm)")
        except Exception as ex:
            print(f"DQN inference error: {ex}")
            action_idx = None

    if action_idx is None or not (0 <= action_idx < len(ACTIONS)):
        sm = sensor.get("sm_root", 0.25)
        action_idx = (0 if sm >= SM_LOW else
                      1 if sm >= 0.19  else
                      2 if sm >= 0.15  else
                      3 if sm >= 0.10  else 4)
        print(f"DQN fallback (FAO-56) → action {action_idx} ({ACTIONS[action_idx]} mm)")

    action_idx = max(0, min(action_idx, len(ACTIONS) - 1))
    recommended = ACTIONS[action_idx]

    precip        = sensor.get("precip_mm", 0.0)
    etc           = sensor.get("et0_mm", 3.0) * sensor.get("kc", 0.85)
    rain_override = precip >= 0.5 * etc
    if rain_override:
        recommended = 0

    return {"recommended_irrigation_mm": recommended, "rain_override": rain_override,
            "dqn_models_used": len(dqn_models)}

# ── Pipeline principal ────────────────────────────────────────────────────────
def run_agent(data: dict) -> dict:
    sm_root  = float(data.get("soil_moisture", 0.25))
    location = data.get("location", "Tunis")

    sensor = {
        "date":          data.get("date", datetime.now().strftime("%Y-%m-%d")),
        "sm_root":       sm_root,
        "sm_shallow":    float(data.get("sm_shallow",    sm_root - 0.01)),
        "sm_deep":       float(data.get("sm_deep",       sm_root + 0.02)),
        "et0_mm":        float(data.get("et0_mm",        3.5)),
        "kc":            float(data.get("kc",            0.85)),
        "precip_mm":     float(data.get("precip_mm",     0.0)),
        "temp_c":        float(data.get("temp_c",        22.0)),
        "rh_pct":        float(data.get("rh_pct",        60.0)),
        "wind_kmh":      float(data.get("wind_kmh",      10.0)),
        "irrigation_mm": float(data.get("irrigation_mm", 0.0)),
        "day_of_season": int(data.get("day_of_season",   45)),
        "growth_stage":  int(data.get("growth_stage",    1)),
    }
    sensor["etc_mm"] = sensor["et0_mm"] * sensor["kc"]

    weather = get_weather(location)
    layer1  = layer1_forecast(sensor)
    rl      = rl_advisor(sensor, layer1["pred_sm_root"], layer1["pred_et0_mm"])
    recommended_mm = rl["recommended_irrigation_mm"]

    if sm_root >= SM_HIGH:   status = "surplus"
    elif sm_root >= SM_LOW:  status = "optimal"
    elif sm_root >= 0.15:    status = "sous_optimal"
    elif sm_root >= 0.10:    status = "faible"
    else:                    status = "critique"

    advice_map = {
        "surplus":      "Sol saturé, aucune irrigation nécessaire.",
        "optimal":      "Humidité dans la bande optimale FAO-56. Pas d'irrigation requise.",
        "sous_optimal": f"Humidité légèrement basse. Irrigation recommandée : {recommended_mm} mm.",
        "faible":       f"Stress hydrique détecté. Irrigation urgente : {recommended_mm} mm.",
        "critique":     f"Stress hydrique sévère ! Irrigation immédiate : {recommended_mm} mm pour éviter les pertes.",
    }

    return {
        "soil_moisture":             sm_root,
        "status":                    status,
        "recommended_irrigation_mm": recommended_mm,
        "advice":                    advice_map[status],
        "pred_sm_root":              round(layer1["pred_sm_root"], 4),
        "pred_et0_mm":               round(layer1["pred_et0_mm"], 3),
        "stress_level":              layer1["stress_level"],
        "rain_override":             rl["rain_override"],
        "dqn_models_used":           rl["dqn_models_used"],
        "weather_tomorrow":          weather,
        "optimal_band":              [SM_LOW, SM_HIGH],
        "available_actions_mm":      ACTIONS,
        "source":                    "pytorch_dqn_ensemble+fao56",
    }

# ── Interface Gradio ──────────────────────────────────────────────────────────
def gradio_predict(soil_moisture, location, et0_mm, precip_mm, kc, day_of_season):
    result = run_agent({
        "soil_moisture": float(soil_moisture),
        "location":      location,
        "et0_mm":        float(et0_mm),
        "precip_mm":     float(precip_mm),
        "kc":            float(kc),
        "day_of_season": int(day_of_season),
    })
    return (
        f"💧 Irrigation recommandée : {result['recommended_irrigation_mm']} mm",
        f"📊 Statut : {result['status']}",
        f"🌱 {result['advice']}",
        f"🌦️ Météo demain : {result['weather_tomorrow'].get('precipitation_mm', 0)} mm pluie, "
        f"ET0={result['weather_tomorrow'].get('et0_forecast_mm', '?')} mm",
        f"🔮 SM prédite demain : {result['pred_sm_root']:.3f}  |  "
        f"🧠 DQN models: {result['dqn_models_used']}/2",
    )

with gr.Blocks(title="AgriSmart Irrigation Agent") as demo:
    gr.Markdown("## 🌾 AgriSmart — Conseiller Irrigation (PyTorch DQN Ensemble + FAO-56)")
    with gr.Row():
        sm_input     = gr.Slider(0.05, 0.40, value=0.20, label="Humidité sol (0-1)")
        loc_input    = gr.Dropdown(list(CITIES.keys()), value="Tunis", label="Ville")
    with gr.Row():
        et0_input    = gr.Slider(0.5, 10.0, value=3.5,  label="ET0 (mm/jour)")
        precip_input = gr.Slider(0.0, 30.0, value=0.0,  label="Précipitations (mm)")
        kc_input     = gr.Slider(0.3, 1.2,  value=0.85, label="Kc (coeff. culture)")
        dos_input    = gr.Slider(1,   228,   value=45,   label="Jour de saison", step=1)
    btn  = gr.Button("🚀 Calculer l'irrigation")
    out1 = gr.Textbox(label="Recommandation")
    out2 = gr.Textbox(label="Statut")
    out3 = gr.Textbox(label="Conseil")
    out4 = gr.Textbox(label="Météo demain")
    out5 = gr.Textbox(label="SM prédite / Modèles")
    btn.click(gradio_predict,
              inputs=[sm_input, loc_input, et0_input, precip_input, kc_input, dos_input],
              outputs=[out1, out2, out3, out4, out5])

# ── Démarrage + routes FastAPI ────────────────────────────────────────────────
launch_result = demo.launch(
    prevent_thread_lock=True,
    server_name="0.0.0.0",
    server_port=7860,
    show_error=True,
)

if launch_result is not None:
    app, _, _ = launch_result

    @app.get("/health")
    def health():
        return {"status": "ok", "dqn_models_loaded": len(dqn_models)}

    @app.post("/irrigate")
    async def irrigate(request: Request):
        body   = await request.json()
        result = run_agent(body)
        return JSONResponse(content=result)

demo.block_thread()
