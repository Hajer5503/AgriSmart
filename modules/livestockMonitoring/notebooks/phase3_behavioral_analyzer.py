import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
class BehavioralAnalyzer:
    def __init__(self):
        self.movement_history = {}
        self.feeding_patterns = {}
        self.social_patterns = {}
        
    def analyze_movement(self, animal_id: str, movement_data: Dict) -> Dict:
        """
        Analyze movement patterns
        movement_data: {timestamp: distance_traveled, step_frequency, etc}
        """
        if animal_id not in self.movement_history:
            self.movement_history[animal_id] = []
        
        self.movement_history[animal_id].append(movement_data)
        
        # Calculate movement metrics
        distances = [m['distance'] for m in self.movement_history[animal_id][-24:]]
        avg_daily_movement = np.mean(distances) if distances else 0
        movement_trend = self._calculate_trend_simple(distances)
        
        # Detect lameness (reduced movement)
        is_limping = avg_daily_movement < 1.5  # km threshold
        
        return {
            'avg_daily_movement_km': avg_daily_movement,
            'movement_trend': movement_trend,
            'lameness_indicator': is_limping,
            'severity': 'High' if is_limping else 'Normal'
        }
    
    def analyze_feeding(self, animal_id: str, feeding_data: Dict) -> Dict:
        """
        Analyze feeding patterns
        feeding_data: {timestamp, amount_eaten, time_spent_eating, etc}
        """
        if animal_id not in self.feeding_patterns:
            self.feeding_patterns[animal_id] = []
        
        self.feeding_patterns[animal_id].append(feeding_data)
        recent_feeding = self.feeding_patterns[animal_id][-7:]
        
        avg_consumption = np.mean([f['amount'] for f in recent_feeding])
        consumption_trend = self._calculate_trend_simple([f['amount'] for f in recent_feeding])
        avg_eating_time = np.mean([f['time_spent'] for f in recent_feeding])
        
        # Detect appetite loss
        appetite_loss = consumption_trend < -0.1
        
        return {
            'avg_daily_consumption_kg': avg_consumption,
            'consumption_trend': consumption_trend,
            'avg_eating_time_minutes': avg_eating_time,
            'appetite_loss_indicator': appetite_loss,
            'recommendations': self._feeding_recommendations(avg_consumption, appetite_loss)
        }
    
    def analyze_social_behavior(self, animal_id: str, social_data: Dict) -> Dict:
        """
        Analyze social interaction patterns
        """
        if animal_id not in self.social_patterns:
            self.social_patterns[animal_id] = []
        
        self.social_patterns[animal_id].append(social_data)
        
        recent_interactions = self.social_patterns[animal_id][-7:]
        interaction_count = len([s for s in recent_interactions if s.get('interaction')])
        
        # Isolation indicator
        is_isolated = interaction_count < 2
        
        return {
            'interaction_count_7days': interaction_count,
            'isolation_indicator': is_isolated,
            'severity': 'High' if is_isolated else 'Normal',
            'note': 'Animal showing isolation - possible illness'if is_isolated else 'Normal social behavior'
        }
    
    def detect_anomalies(self, animal_id: str) -> List[Dict]:
        """Detect behavioral anomalies"""
        anomalies = []
        
        # Movement anomalies
        if animal_id in self.movement_history:
            movement_analysis = self.analyze_movement(
                animal_id, 
                self.movement_history[animal_id][-1]
            )
            if movement_analysis['lameness_indicator']:
                anomalies.append({
                    'type': 'Lameness',
                    'severity': 'High',
                    'action': 'Check hooves and legs'
                })
        
        # Feeding anomalies
        if animal_id in self.feeding_patterns:
            feeding_analysis = self.analyze_feeding(
                animal_id,
                self.feeding_patterns[animal_id][-1]
            )
            if feeding_analysis['appetite_loss_indicator']:
                anomalies.append({
                    'type': 'Appetite Loss',
                    'severity': 'High',
                    'action': 'Consult veterinarian'
                })
        
        # Social anomalies
        if animal_id in self.social_patterns:
            social_analysis = self.analyze_social_behavior(
                animal_id,
                self.social_patterns[animal_id][-1]
            )
            if social_analysis['isolation_indicator']:
                anomalies.append({
                    'type': 'Social Isolation',
                    'severity': 'Medium',
                    'action': 'Monitor closely'
                })
        
        return anomalies
    
    def _calculate_trend_simple(self, values: List[float]) -> float:
        """Calculate simple trend"""
        if len(values) < 2:
            return 0.0
        
        recent = np.mean(values[-3:])
        previous = np.mean(values[:-3])
        
        if previous == 0:
            return 0.0
        
        return (recent - previous) / previous
    
    def _feeding_recommendations(self, avg_consumption: float, appetite_loss: bool) -> List[str]:
        recommendations = []
        
        if appetite_loss:
            recommendations.append("📌 Increase feed palatability")
            recommendations.append("📌 Check water availability")
            recommendations.append("📌 Monitor for illness signs")
        elif avg_consumption < 5:
            recommendations.append("📌 Increase feed quantity")
            recommendations.append("📌 Check feed quality")
        else:
            recommendations.append("✅ Feeding patterns normal")
        
        return recommendations
    
    def generate_behavior_score(self, animal_id: str) -> Dict:
        """Generate overall behavior health score"""
        score = 100  # Start at perfect
        issues = []
        
        if animal_id in self.movement_history:
            movement_analysis = self.analyze_movement(
                animal_id,
                self.movement_history[animal_id][-1]
            )
            if movement_analysis['lameness_indicator']:
                score -= 30
                issues.append('Lameness detected')
        
        if animal_id in self.feeding_patterns:
            feeding_analysis = self.analyze_feeding(
                animal_id,
                self.feeding_patterns[animal_id][-1]
            )
            if feeding_analysis['appetite_loss_indicator']:
                score -= 25
                issues.append('Appetite loss')
        
        if animal_id in self.social_patterns:
            social_analysis = self.analyze_social_behavior(
                animal_id,
                self.social_patterns[animal_id][-1]
            )
            if social_analysis['isolation_indicator']:
                score -= 20
                issues.append('Social isolation')
        
        return {
            'animal_id': animal_id,
            'behavior_score': max(0, score),
            'status': 'Critical' if score < 40 else 'Warning' if score < 70 else 'Normal',
            'issues': issues
        }