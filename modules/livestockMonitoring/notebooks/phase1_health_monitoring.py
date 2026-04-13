import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from enum import Enum

class HealthStatus(Enum):
    EXCELLENT = "Excellent"
    GOOD = "Good"
    MODERATE = "Moderate"
    POOR = "Poor"
    CRITICAL = "Critical"

@dataclass
class VitalSigns:
    animal_id: str
    timestamp: str
    body_temperature: float  # Celsius
    heart_rate: int  # BPM
    respiratory_rate: int  # Breaths/min
    body_condition_score: float  # 1-5
    weight: float  # kg
    
    def to_dict(self):
        return asdict(self)

class HealthMonitor:
    def __init__(self):
        self.vital_signs_history = {}
        self.health_scores = {}
        
        self.normal_ranges = {
            'cattle': {
                'body_temperature': (37.5, 39.3),
                'heart_rate': (40, 80),
                'respiratory_rate': (10, 30),
                'body_condition_score': (2.5, 3.5)
            },
            'sheep': {
                'body_temperature': (38.5, 39.5),
                'heart_rate': (60, 120),
                'respiratory_rate': (12, 20),
                'body_condition_score': (2.0, 3.0)
            },
            'goat': {
                'body_temperature': (38.5, 40.0),
                'heart_rate': (70, 135),
                'respiratory_rate': (15, 30),
                'body_condition_score': (2.5, 3.0)
            },
            'pig': {
                'body_temperature': (38.5, 39.7),
                'heart_rate': (70, 100),
                'respiratory_rate': (10, 20),
                'body_condition_score': (2.0, 3.5)
            }
        }
        
    def check_vital_signs(self, vital_signs: VitalSigns, species: str = 'cattle') -> Dict:
        ranges = self.normal_ranges.get(species, self.normal_ranges['cattle'])
        abnormalities = {}
        severity_scores = {}
        
        # Temperature check
        temp_min, temp_max = ranges['body_temperature']
        if vital_signs.body_temperature < temp_min:
            abnormalities['hypothermia'] = {
                'value': vital_signs.body_temperature,
                'deviation': temp_min - vital_signs.body_temperature
            }
            severity_scores['temperature'] = self._calculate_severity(
                vital_signs.body_temperature, temp_min, temp_max, 'low'
            )
        elif vital_signs.body_temperature > temp_max:
            abnormalities['fever'] = {
                'value': vital_signs.body_temperature,
                'deviation': vital_signs.body_temperature - temp_max
            }
            severity_scores['temperature'] = self._calculate_severity(
                vital_signs.body_temperature, temp_min, temp_max, 'high'
            )
        
        # Heart rate check
        hr_min, hr_max = ranges['heart_rate']
        if vital_signs.heart_rate < hr_min:
            abnormalities['bradycardia'] = {'value': vital_signs.heart_rate}
            severity_scores['heart_rate'] = self._calculate_severity(
                vital_signs.heart_rate, hr_min, hr_max, 'low'
            )
        elif vital_signs.heart_rate > hr_max:
            abnormalities['tachycardia'] = {'value': vital_signs.heart_rate}
            severity_scores['heart_rate'] = self._calculate_severity(
                vital_signs.heart_rate, hr_min, hr_max, 'high'
            )
        
        # Respiratory rate check
        rr_min, rr_max = ranges['respiratory_rate']
        if vital_signs.respiratory_rate < rr_min:
            abnormalities['bradypnea'] = {'value': vital_signs.respiratory_rate}
            severity_scores['respiratory_rate'] = self._calculate_severity(
                vital_signs.respiratory_rate, rr_min, rr_max, 'low'
            )
        elif vital_signs.respiratory_rate > rr_max:
            abnormalities['tachypnea'] = {'value': vital_signs.respiratory_rate}
            severity_scores['respiratory_rate'] = self._calculate_severity(
                vital_signs.respiratory_rate, rr_min, rr_max, 'high'
            )
        
        # Body condition check
        bcs_min, bcs_max = ranges['body_condition_score']
        if vital_signs.body_condition_score < bcs_min:
            abnormalities['underweight'] = {
                'value': vital_signs.body_condition_score,
                'risk': 'Inadequate nutrition'
            }
        elif vital_signs.body_condition_score > bcs_max:
            abnormalities['overweight'] = {
                'value': vital_signs.body_condition_score,
                'risk': 'Metabolic stress'
            }
        
        return {
            'abnormalities': abnormalities,
            'severity_scores': severity_scores,
            'overall_severity': np.mean(list(severity_scores.values())) if severity_scores else 0
        }
    
    def _calculate_severity(self, value, min_val, max_val, direction):
        if direction == 'high':
            deviation = value - max_val
            max_deviation = max_val * 0.3
        else:
            deviation = min_val - value
            max_deviation = min_val * 0.3
        
        severity = min(1.0, deviation / max_deviation) if max_deviation > 0 else 0
        return float(severity)
    
    def predict_health_status(self, vital_signs: VitalSigns, species: str = 'cattle',
                             historical_data: Optional[List[VitalSigns]] = None) -> Tuple[HealthStatus, float]:
        vitals_check = self.check_vital_signs(vital_signs, species)
        overall_severity = vitals_check['overall_severity']
        
        trend_factor = 0.0
        if historical_data and len(historical_data) > 1:
            trend_factor = self._calculate_trend(historical_data, vital_signs, species)
        
        combined_score = (overall_severity * 0.7) + (trend_factor * 0.3)
        
        if combined_score < 0.2:
            status = HealthStatus.EXCELLENT
            confidence = 0.95 - combined_score
        elif combined_score < 0.4:
            status = HealthStatus.GOOD
            confidence = 0.90 - (combined_score * 0.2)
        elif combined_score < 0.6:
            status = HealthStatus.MODERATE
            confidence = 0.85 - (combined_score * 0.1)
        elif combined_score < 0.8:
            status = HealthStatus.POOR
            confidence = 0.80 - (combined_score * 0.05)
        else:
            status = HealthStatus.CRITICAL
            confidence = min(0.95, 0.75 + (combined_score * 0.2))
        
        if vital_signs.animal_id not in self.vital_signs_history:
            self.vital_signs_history[vital_signs.animal_id] = []
        self.vital_signs_history[vital_signs.animal_id].append(vital_signs)
        self.health_scores[vital_signs.animal_id] = status.value
        
        return status, confidence
    
    def _calculate_trend(self, historical_data: List[VitalSigns], 
                        current_data: VitalSigns, species: str) -> float:
        if len(historical_data) < 2:
            return 0.0
        
        trends = []
        for i in range(1, len(historical_data)):
            prev = historical_data[i-1]
            curr = historical_data[i]
            
            temp_trend = abs((curr.body_temperature - prev.body_temperature) / prev.body_temperature)
            trends.append(temp_trend)
            
            hr_trend = abs((curr.heart_rate - prev.heart_rate) / prev.heart_rate)
            trends.append(hr_trend)
        
        return float(np.mean(trends)) if trends else 0.0
    
    def generate_health_report(self, animal_id: str, species: str = 'cattle') -> Dict:
        if animal_id not in self.vital_signs_history:
            return {'error': 'No data for animal'}
        
        history = self.vital_signs_history[animal_id]
        latest = history[-1]
        vitals_check = self.check_vital_signs(latest, species)
        
        report = {
            'animal_id': animal_id,
            'timestamp': latest.timestamp,
            'species': species,
            'current_status': self.health_scores.get(animal_id, 'Unknown'),
            'vital_signs': latest.to_dict(),
            'abnormalities': vitals_check['abnormalities'],
            'observations': []
        }
        
        if vitals_check['abnormalities']:
            report['observations'].append(
                f"⚠️ {len(vitals_check['abnormalities'])} abnormalities detected"
            )
        else:
            report['observations'].append("✅ All vital signs within normal range")
        
        if vitals_check['severity_scores']:
            most_severe = max(vitals_check['severity_scores'], 
                            key=vitals_check['severity_scores'].get)
            report['observations'].append(
                f"📌 Priority: Monitor {most_severe}"
            )
        
        return report