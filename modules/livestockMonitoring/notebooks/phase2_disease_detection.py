import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from phase1_health_monitoring import HealthMonitor, VitalSigns, HealthStatus
from phase3_behavioral_analyzer import BehavioralAnalyzer
from phase4_nutrition_optimizer import NutritionOptimizer
class DiseaseProfile:
    def __init__(self, disease_name: str, species: List[str], symptoms: Dict[str, Dict]):
        self.disease_name = disease_name
        self.affected_species = species
        self.symptoms = symptoms

class DiseaseDetector:
    def __init__(self):
        self.diseases = {}
        self._initialize_disease_database()
        
    def _initialize_disease_database(self):
        # Bovine Respiratory Disease (BRD)
        self.diseases['BRD'] = DiseaseProfile(
            disease_name='Bovine Respiratory Disease',
            species=['cattle'],
            symptoms={
                'elevated_respiratory_rate': {'weight': 0.25, 'threshold': 40},
                'fever': {'weight': 0.25, 'threshold': 39.5},
                'lethargy': {'weight': 0.20, 'indicator': 'low_movement'},
                'nasal_discharge': {'weight': 0.15, 'indicator': 'present'},
                'cough': {'weight': 0.15, 'indicator': 'present'}
            }
        )
        
        # Mastitis
        self.diseases['Mastitis'] = DiseaseProfile(
            disease_name='Mastitis',
            species=['cattle'],
            symptoms={
                'fever': {'weight': 0.20, 'threshold': 39.3},
                'udder_inflammation': {'weight': 0.30, 'indicator': 'present'},
                'milk_changes': {'weight': 0.25, 'indicator': 'clots_or_blood'},
                'lameness': {'weight': 0.15, 'indicator': 'observed'},
                'weight_loss': {'weight': 0.10, 'threshold': -0.5}
            }
        )
        
        # Foot and Mouth Disease
        self.diseases['FMD'] = DiseaseProfile(
            disease_name='Foot and Mouth Disease',
            species=['cattle', 'sheep', 'goat', 'pig'],
            symptoms={
                'fever': {'weight': 0.25, 'threshold': 39.5},
                'lameness': {'weight': 0.25, 'indicator': 'severe'},
                'blisters': {'weight': 0.30, 'indicator': 'present'},
                'reduced_milk': {'weight': 0.10, 'indicator': 'present'},
                'excessive_salivation': {'weight': 0.10, 'indicator': 'present'}
            }
        )
        
        # Pneumonia
        self.diseases['Pneumonia'] = DiseaseProfile(
            disease_name='Pneumonia',
            species=['cattle', 'sheep'],
            symptoms={
                'elevated_respiratory_rate': {'weight': 0.30, 'threshold': 40},
                'fever': {'weight': 0.25, 'threshold': 39.5},
                'cough': {'weight': 0.20, 'indicator': 'persistent'},
                'nasal_discharge': {'weight': 0.15, 'indicator': 'present'},
                'depression': {'weight': 0.10, 'indicator': 'observed'}
            }
        )
        
        # Scours (Diarrhea)
        self.diseases['Scours'] = DiseaseProfile(
            disease_name='Scours (Diarrhea)',
            species=['cattle', 'sheep', 'goat'],
            symptoms={
                'diarrhea': {'weight': 0.40, 'indicator': 'present'},
                'dehydration': {'weight': 0.25, 'indicator': 'severe'},
                'weight_loss': {'weight': 0.20, 'threshold': -1.0},
                'fever': {'weight': 0.10, 'threshold': 39.0},
                'lethargy': {'weight': 0.05, 'indicator': 'observed'}
            }
        )
        
        # Brucellosis
        self.diseases['Brucellosis'] = DiseaseProfile(
            disease_name='Brucellosis',
            species=['cattle', 'sheep', 'goat'],
            symptoms={
                'reproductive_issues': {'weight': 0.35, 'indicator': 'abortion'},
                'fever': {'weight': 0.20, 'threshold': 39.2},
                'infertility': {'weight': 0.25, 'indicator': 'observed'},
                'joint_swelling': {'weight': 0.15, 'indicator': 'present'},
                'lethargy': {'weight': 0.05, 'indicator': 'observed'}
            }
        )
        
    def detect_disease(self, vital_signs: VitalSigns, clinical_signs: Dict, 
                      species: str) -> List[Tuple[str, float]]:
        detected_diseases = []
        
        for disease_name, disease_profile in self.diseases.items():
            if species not in disease_profile.affected_species:
                continue
            
            probability = self._calculate_disease_probability(
                vital_signs, clinical_signs, disease_profile
            )
            
            if probability > 0.3:
                detected_diseases.append((disease_name, probability))
        
        detected_diseases.sort(key=lambda x: x[1], reverse=True)
        return detected_diseases
    
    def _calculate_disease_probability(self, vital_signs: VitalSigns, 
                                       clinical_signs: Dict, 
                                       disease_profile: DiseaseProfile) -> float:
        probabilities = []
        
        for symptom, symptom_profile in disease_profile.symptoms.items():
            if symptom not in clinical_signs and symptom != 'fever' and \
               symptom != 'elevated_respiratory_rate':
                continue
            
            if symptom == 'fever':
                if vital_signs.body_temperature >= symptom_profile['threshold']:
                    temp_prob = self._assess_severity(
                        vital_signs.body_temperature,
                        symptom_profile['threshold'],
                        symptom_profile['threshold'] + 2.0
                    )
                    probabilities.append(temp_prob * symptom_profile['weight'])
                    
            elif symptom == 'elevated_respiratory_rate':
                if vital_signs.respiratory_rate >= symptom_profile['threshold']:
                    rr_prob = self._assess_severity(
                        vital_signs.respiratory_rate,
                        symptom_profile['threshold'],
                        symptom_profile['threshold'] + 20
                    )
                    probabilities.append(rr_prob * symptom_profile['weight'])
            
            elif symptom in clinical_signs:
                sign_value = clinical_signs[symptom]
                if 'indicator' in symptom_profile:
                    if sign_value == symptom_profile['indicator'] or sign_value:
                        probabilities.append(symptom_profile['weight'])
                elif 'threshold' in symptom_profile:
                    if sign_value <= symptom_profile['threshold']:
                        prob = self._assess_severity(
                            sign_value,
                            symptom_profile['threshold'] - 1.0,
                            symptom_profile['threshold']
                        )
                        probabilities.append(prob * symptom_profile['weight'])
        
        if probabilities:
            total_weight = sum([p[1]["weight"] for p in disease_profile.symptoms.items()])
            avg_probability = np.mean(probabilities) / total_weight * 1.5
            return min(1.0, float(avg_probability))
        
        return 0.0
    
    def _assess_severity(self, value: float, threshold1: float, 
                        threshold2: float) -> float:
        if value <= threshold1:
            return 0.0
        elif value >= threshold2:
            return 1.0
        else:
            return (value - threshold1) / (threshold2 - threshold1)
    
    def get_disease_details(self, disease_name: str) -> Dict:
        if disease_name not in self.diseases:
            return {'error': 'Disease not found'}
        
        disease = self.diseases[disease_name]
        return {
            'name': disease.disease_name,
            'affected_species': disease.affected_species,
            'symptoms': disease.symptoms,
            'recommendation': f'⚠️ Suspected {disease.disease_name}. Consult veterinarian immediately.'
        }