# ============================================================================
# MASTER UNIFIED LIVESTOCK HEALTH AI AGENT
# Integrates all 5 phases into one comprehensive system
# livestock_health_agent/unified_livestock_health_agent.py
# ============================================================================

import json
from datetime import datetime
from typing import Dict, List, Tuple
from dataclasses import dataclass

# Import all phases
from .phase1_health_monitoring import HealthMonitor, HealthStatus, VitalSigns
from .phase2_disease_detection import DiseaseDetector
from .phase3_behavioral_analyzer import BehavioralAnalyzer
from .phase4_nutrition_optimizer import NutritionOptimizer
from .phase5_alert_system import AlertSystem, AlertType, AlertSeverity

@dataclass
class AnimalRecord:
    """Complete animal record linking all phases"""
    animal_id: str
    species: str
    weight: float
    age: int
    vital_signs: VitalSigns
    clinical_signs: Dict
    movement_data: Dict = None
    feeding_data: Dict = None
    stage: str = "maintenance"
    milk_production: float = 0.0
    timestamp: str = None
    
    def to_dict(self):
        return {
            'animal_id': self.animal_id,
            'species': self.species,
            'weight': self.weight,
            'age': self.age,
            'vital_signs': self.vital_signs.to_dict(),
            'clinical_signs': self.clinical_signs,
            'movement_data': self.movement_data,
            'feeding_data': self.feeding_data,
            'stage': self.stage,
            'milk_production': self.milk_production,
            'timestamp': self.timestamp or datetime.now().isoformat()
        }

class UnifiedLivestockHealthAgent:
    """
    Master agent that integrates all 5 phases:
    1. Health Monitoring
    2. Disease Detection
    3. Behavioral Analysis
    4. Nutrition Optimization
    5. Alert System
    """
    
    def __init__(self):
        """Initialize all components"""
        print("\n" + "="*80)
        print("🚀 INITIALIZING UNIFIED LIVESTOCK HEALTH AI AGENT")
        print("="*80)
        
        self.health_monitor = HealthMonitor()
        print("✅ Phase 1: Health Monitor initialized")
        
        self.disease_detector = DiseaseDetector()
        print("✅ Phase 2: Disease Detector initialized")
        
        self.behavioral_analyzer = BehavioralAnalyzer()
        print("✅ Phase 3: Behavioral Analyzer initialized")
        
        self.nutrition_optimizer = NutritionOptimizer()
        print("✅ Phase 4: Nutrition Optimizer initialized")
        
        self.alert_system = AlertSystem()
        print("✅ Phase 5: Alert System initialized")
        
        self.animal_records = {}
        self.analysis_history = []
        
        print("\n✅ ALL PHASES LINKED AND READY!")
        print("="*80 + "\n")
    
    def process_animal_data(self, animal_record: AnimalRecord) -> Dict:
        """Main method - Process animal through all 5 phases"""
        
        animal_id = animal_record.animal_id
        species = animal_record.species
        
        print(f"\n{'='*80}")
        print(f"🔍 PROCESSING ANIMAL: {animal_id} ({species})")
        print(f"{'='*80}")
        
        # PHASE 1
        print(f"\n📊 PHASE 1: HEALTH MONITORING")
        print("-" * 80)
        
        health_status, health_confidence = self.health_monitor.predict_health_status(
            animal_record.vital_signs, species=species
        )
        
        phase1_result = {
            'health_status': health_status.value,
            'confidence': health_confidence,
            'vital_signs': animal_record.vital_signs.to_dict()
        }
        
        print(f"✅ Health Status: {health_status.value}")
        print(f"✅ Confidence: {health_confidence:.1%}")
        
        # PHASE 2
        print(f"\n🦠 PHASE 2: DISEASE DETECTION")
        print("-" * 80)
        
        diseases = self.disease_detector.detect_disease(
            animal_record.vital_signs,
            animal_record.clinical_signs,
            species
        )
        
        phase2_result = {
            'detected_diseases': [(d[0], f"{d[1]:.1%}") for d in diseases]
        }
        
        print(f"✅ Diseases Detected: {len(diseases)}")
        for disease_name, probability in diseases[:3]:
            print(f"   • {disease_name}: {probability:.1%}")
        
        # PHASE 3
        print(f"\n👀 PHASE 3: BEHAVIORAL ANALYSIS")
        print("-" * 80)
        
        anomalies = self.behavioral_analyzer.detect_anomalies(animal_id)
        behavior_score = self.behavioral_analyzer.generate_behavior_score(animal_id)
        
        phase3_result = {
            'behavior_score': behavior_score['behavior_score'],
            'behavior_status': behavior_score['status'],
            'behavioral_issues': behavior_score['issues'],
            'anomalies': anomalies
        }
        
        print(f"✅ Behavior Score: {behavior_score['behavior_score']}/100")
        print(f"✅ Status: {behavior_score['status']}")
        
        # PHASE 4
        print(f"\n🌾 PHASE 4: NUTRITION OPTIMIZATION")
        print("-" * 80)
        
        nutrition_data = {
            'species': species,
            'weight': animal_record.weight,
            'stage': animal_record.stage,
            'milk_production_liters': animal_record.milk_production
        }
        
        nutrition_plan = self.nutrition_optimizer.recommend_diet(nutrition_data)
        
        phase4_result = {
            'nutritional_requirements': nutrition_plan['requirements'],
            'recommended_feed': nutrition_plan['recommended_feed'],
            'feeding_schedule': nutrition_plan['feeding_schedule']
        }
        
        print(f"✅ Energy Required: {nutrition_plan['requirements']['energy_mcal']:.1f} Mcal")
        print(f"✅ Daily Feed: {nutrition_plan['recommended_feed']['daily_amount_kg']} kg")
        
        # PHASE 5
        print(f"\n🚨 PHASE 5: ALERT SYSTEM")
        print("-" * 80)
        
        alerts_generated = []
        
        if health_status.value in ['Poor', 'Critical']:
            severity = AlertSeverity.CRITICAL if health_status.value == 'Critical' else AlertSeverity.HIGH
            alert = self.alert_system.generate_alert(
                AlertType.CRITICAL_EMERGENCY if health_status.value == 'Critical' else AlertType.HEALTH_WARNING,
                severity,
                animal_id,
                f"Health Status ALERT: {health_status.value}",
                phase1_result
            )
            alerts_generated.append(alert)
        
        if diseases:
            for disease_name, probability in diseases[:3]:
                if probability > 0.5:
                    severity = AlertSeverity.CRITICAL if probability > 0.8 else AlertSeverity.HIGH
                    alert = self.alert_system.generate_alert(
                        AlertType.DISEASE_ALERT,
                        severity,
                        animal_id,
                        f"Disease Risk: {disease_name} ({probability:.1%})",
                        {'disease': disease_name, 'probability': probability}
                    )
                    alerts_generated.append(alert)
        
        if behavior_score['status'] == 'Critical':
            alert = self.alert_system.generate_alert(
                AlertType.BEHAVIOR_ANOMALY,
                AlertSeverity.HIGH,
                animal_id,
                f"Behavioral Anomaly: {', '.join(behavior_score['issues'])}",
                phase3_result
            )
            alerts_generated.append(alert)
        
        print(f"✅ Alerts Generated: {len(alerts_generated)}")
        
        # COMPREHENSIVE REPORT
        comprehensive_report = {
            'animal_id': animal_id,
            'timestamp': animal_record.timestamp or datetime.now().isoformat(),
            'species': species,
            'phase_1_health_monitoring': phase1_result,
            'phase_2_disease_detection': phase2_result,
            'phase_3_behavioral_analysis': phase3_result,
            'phase_4_nutrition_optimization': phase4_result,
            'phase_5_alerts': {
                'total_alerts': len(alerts_generated),
                'alerts': [alert.to_dict() for alert in alerts_generated],
                'statistics': self.alert_system.get_alert_statistics()
            },
            'unified_recommendations': self._generate_recommendations(
                health_status, diseases, behavior_score
            )
        }
        
        self.animal_records[animal_id] = comprehensive_report
        self.analysis_history.append(comprehensive_report)
        
        return comprehensive_report
    
    def _generate_recommendations(self, health_status: HealthStatus, 
                                 diseases: List, behavior_score: Dict) -> List[str]:
        """Generate unified recommendations"""
        recommendations = []
        
        if health_status.value in ['Poor', 'Critical']:
            recommendations.append("🚨 URGENT: Contact veterinarian immediately")
        
        if diseases:
            recommendations.append(f"🔍 Monitor for: {diseases[0][0]}")
        
        if behavior_score['status'] == 'Critical':
            recommendations.append("👀 Increase monitoring frequency")
        
        recommendations.append("📋 Document all observations")
        recommendations.append("🔄 Recheck vitals in 24 hours")
        
        return recommendations
    
    def generate_farm_report(self) -> Dict:
        """Generate farm-level report"""
        print(f"\n{'='*80}")
        print(f"📊 FARM COMPREHENSIVE REPORT")
        print(f"{'='*80}")
        
        total_animals = len(self.animal_records)
        
        if total_animals == 0:
            return {'error': 'No animals analyzed'}
        
        health_statuses = [r['phase_1_health_monitoring']['health_status'] for r in self.animal_records.values()]
        
        report = {
            'total_animals': total_animals,
            'health_summary': {
                'excellent': health_statuses.count('Excellent'),
                'good': health_statuses.count('Good'),
                'moderate': health_statuses.count('Moderate'),
                'poor': health_statuses.count('Poor'),
                'critical': health_statuses.count('Critical')
            },
            'farm_health_percentage': ((health_statuses.count('Excellent') + health_statuses.count('Good')) / total_animals * 100),
            'alert_statistics': self.alert_system.get_alert_statistics()
        }
        
        return report

# Usage example
if __name__ == "__main__":
    agent = UnifiedLivestockHealthAgent()
    
    # Example animal
    vitals = VitalSigns(
        animal_id='DOG-001',
        timestamp=datetime.now().isoformat(),
        body_temperature=39.5,
        heart_rate=120,
        respiratory_rate=28,
        body_condition_score=2.8,
        weight=30.0
    )
    
    record = AnimalRecord(
        animal_id='DOG-001',
        species='cattle',
        weight=30.0,
        age=4,
        vital_signs=vitals,
        clinical_signs={'fever': True, 'lethargy': True},
        stage='maintenance'
    )
    
    analysis = agent.process_animal_data(record)
    print(json.dumps(analysis, indent=2, default=str))