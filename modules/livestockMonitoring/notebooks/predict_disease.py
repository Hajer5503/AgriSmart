# ============================================================================
# predict_disease.py
# Bridge between farmer input and the trained Random Forest model.
#
# Uses the EXACT same feature engineering as the professor-validated notebook:
#   Normalized : Age, Weight, Duration_Days, Body_Temperature_C,
#                Heart_Rate, temp_deviation
#   Binary flags: Appetite_Loss, Vomiting, Diarrhea, Coughing,
#                 Labored_Breathing, Lameness, Skin_Lesions,
#                 Nasal_Discharge, Eye_Discharge
#   Engineered  : symptom_count, is_fever, high_heart_rate
#   Categorical : Gender_bin, Breed_encoded, animal_* one-hots
# ============================================================================

import os, pickle, json
import numpy as np

_DIR   = os.path.dirname(os.path.abspath(__file__))
_MODEL = os.path.join(_DIR, "rf_model_final.pkl")
_LABEL = os.path.join(_DIR, "disease_label_map.json")
_RULES = os.path.join(_DIR, "llm_rules.txt")

_bundle = None
_lmap   = None
_rules  = None

BINARY_FLAGS = [
    'Appetite_Loss','Vomiting','Diarrhea','Coughing',
    'Labored_Breathing','Lameness','Skin_Lesions',
    'Nasal_Discharge','Eye_Discharge'
]
FEVER_THRESHOLD   = 39.5
NORMAL_TEMP_MID   = 38.5
HIGH_HR_THRESHOLD = 120
ANIMAL_TYPES = ['Cat','Cow','Dog','Goat','Horse','Pig','Rabbit','Sheep']

SYMPTOM_TO_FLAG = {
    'coughing':'Coughing','cough':'Coughing',
    'diarrhea':'Diarrhea','diarrhoea':'Diarrhea','loose stool':'Diarrhea',
    'vomiting':'Vomiting','vomit':'Vomiting','nausea':'Vomiting',
    'appetite loss':'Appetite_Loss','loss of appetite':'Appetite_Loss',
    'anorexia':'Appetite_Loss','not eating':'Appetite_Loss',
    'reduced appetite':'Appetite_Loss','no appetite':'Appetite_Loss',
    'labored breathing':'Labored_Breathing','difficulty breathing':'Labored_Breathing',
    'laboured breathing':'Labored_Breathing','breathing difficulty':'Labored_Breathing',
    'lameness':'Lameness','limping':'Lameness','lame':'Lameness',
    'skin lesions':'Skin_Lesions','lesions':'Skin_Lesions','skin sores':'Skin_Lesions',
    'nasal discharge':'Nasal_Discharge','runny nose':'Nasal_Discharge',
    'eye discharge':'Eye_Discharge','eye secretion':'Eye_Discharge',
}

DEFAULT_WEIGHTS = {
    'Dog':20,'Cat':4,'Cow':500,'Horse':500,
    'Sheep':70,'Goat':60,'Pig':100,'Rabbit':2
}


def _load():
    global _bundle, _lmap, _rules
    if _bundle is None:
        with open(_MODEL,'rb') as f:
            _bundle = pickle.load(f)
    if _lmap is None:
        with open(_LABEL) as f:
            _lmap = json.load(f)
    if _rules is None:
        with open(_RULES,encoding='utf-8') as f:
            _rules = f.read()


def get_rules_for_animal(animal_type: str) -> str:
    _load()
    lines  = _rules.split('\n')
    header = f"  {animal_type.upper()} "
    start  = None
    end    = None
    for i, line in enumerate(lines):
        if header in line and '─' in lines[max(0,i-1)]:
            start = i - 1
        elif start is not None and '─'*10 in line and i > start + 2:
            end = i
            break
    if start is None:
        return f"(No rules found for {animal_type})"
    return '\n'.join(lines[start: end or len(lines)])


def predict_disease(
    animal_type:   str,
    symptoms:      list  = None,
    binary_flags:  dict  = None,
    body_temp:     float = None,
    heart_rate:    float = None,
    age:           float = 3.0,
    weight:        float = None,
    gender:        str   = 'Female',
    duration_days: int   = 7,
    top_n:         int   = 3,
) -> dict:
    _load()

    rf            = _bundle['model']
    FEATURE_COLS  = _bundle['feature_cols']
    id_to_disease = _bundle['id_to_disease']
    scaler_params = _lmap['scaler_params']

    animal_type = animal_type.strip().capitalize()
    if animal_type not in ANIMAL_TYPES:
        matches = [a for a in ANIMAL_TYPES if a.lower() == animal_type.lower()]
        animal_type = matches[0] if matches else 'Dog'

    weight     = weight    or DEFAULT_WEIGHTS.get(animal_type, 100)
    body_temp  = body_temp  or 39.0
    heart_rate = heart_rate or 70.0

    binary_flags = dict(binary_flags or {})
    for sym in (symptoms or []):
        s = sym.strip().lower()
        if s in SYMPTOM_TO_FLAG:
            binary_flags.setdefault(SYMPTOM_TO_FLAG[s], 1)
        if s in ('fever','high temperature','hyperthermia'):
            if body_temp < FEVER_THRESHOLD:
                body_temp = 40.0

    temp_deviation = body_temp - NORMAL_TEMP_MID
    is_fever       = int(body_temp > FEVER_THRESHOLD)
    high_hr        = int(heart_rate > HIGH_HR_THRESHOLD)
    symptom_count  = sum(binary_flags.get(f, 0) for f in BINARY_FLAGS)
    gender_bin     = 1 if gender.strip().lower() == 'male' else 0

    def norm(val, col):
        p   = scaler_params.get(col, {'min':0,'max':1})
        rng = p['max'] - p['min']
        return round((val - p['min']) / rng, 4) if rng > 0 else 0.0

    animal_ohe = {f'animal_{a}': int(a == animal_type) for a in ANIMAL_TYPES}

    row_dict = {
        'Age_norm':                norm(age,            'Age'),
        'Weight_norm':             norm(weight,         'Weight'),
        'Duration_Days_norm':      norm(duration_days,  'Duration_Days'),
        'Body_Temperature_C_norm': norm(body_temp,      'Body_Temperature_C'),
        'Heart_Rate_norm':         norm(heart_rate,     'Heart_Rate'),
        'temp_deviation_norm':     norm(temp_deviation, 'temp_deviation'),
        **{f+'_bin': binary_flags.get(f, 0) for f in BINARY_FLAGS},
        'symptom_count':   symptom_count,
        'is_fever':        is_fever,
        'high_heart_rate': high_hr,
        'Gender_bin':      gender_bin,
        'Breed_encoded':   0,
        **animal_ohe,
    }

    row   = [row_dict.get(col, 0) for col in FEATURE_COLS]
    proba = rf.predict_proba([row])[0]

    results = sorted(
        [{'disease': id_to_disease.get(str(int(c)), f'ID_{c}'),
          'probability': round(float(p), 3)}
         for c, p in zip(rf.classes_, proba)],
        key=lambda x: -x['probability']
    )

    return {
        'animal':          animal_type,
        'top_predictions': results[:top_n],
        'model_top3_acc':  _bundle.get('top3_accuracy', 0.40),
        'note': (
            f"RF top-3 accuracy: {_bundle.get('top3_accuracy',0.40)*100:.0f}%. "
            "Verify with clinical exam."
        )
    }


if __name__ == '__main__':
    print("Test 1 — Cow, fever + coughing + nasal discharge")
    r = predict_disease('Cow',
        symptoms=['fever','coughing','nasal discharge'],
        binary_flags={'Coughing':1,'Nasal_Discharge':1,'Appetite_Loss':1},
        body_temp=40.1, heart_rate=90, age=4, duration_days=5)
    for p in r['top_predictions']:
        print(f"  {p['disease']:<42} {p['probability']*100:5.1f}%")

    print("\nTest 2 — Dog, vomiting + diarrhea")
    r = predict_disease('Dog',
        symptoms=['vomiting','diarrhea','not eating'],
        body_temp=39.5, heart_rate=130, age=2, duration_days=3)
    for p in r['top_predictions']:
        print(f"  {p['disease']:<42} {p['probability']*100:5.1f}%")
