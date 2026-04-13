from enum import Enum as AlertEnum
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from phase1_health_monitoring import HealthMonitor, VitalSigns, HealthStatus
from phase2_disease_detection import DiseaseDetector
from phase3_behavioral_analyzer import BehavioralAnalyzer
from phase4_nutrition_optimizer import NutritionOptimizer

class AlertSeverity(AlertEnum):
    LOW = "Low"
    MEDIUM = "Medium"
    HIGH = "High"
    CRITICAL = "Critical"

class AlertType(AlertEnum):
    HEALTH_WARNING = "Health Warning"
    DISEASE_ALERT = "Disease Alert"
    BEHAVIOR_ANOMALY = "Behavior Anomaly"
    NUTRITION_WARNING = "Nutrition Warning"
    CRITICAL_EMERGENCY = "Critical Emergency"

class Alert:
    def __init__(self, alert_type: AlertType, severity: AlertSeverity,
                 animal_id: str, message: str, data: Dict):
        self.alert_id = f"ALT-{datetime.now().timestamp()}"
        self.alert_type = alert_type
        self.severity = severity
        self.animal_id = animal_id
        self.message = message
        self.data = data
        self.timestamp = datetime.now()
        self.acknowledged = False
        self.actions_taken = []
    
    def to_dict(self):
        return {
            'alert_id': self.alert_id,
            'type': self.alert_type.value,
            'severity': self.severity.value,
            'animal_id': self.animal_id,
            'message': self.message,
            'timestamp': self.timestamp.isoformat(),
            'acknowledged': self.acknowledged,
            'data': self.data
        }

class AlertSystem:
    def __init__(self):
        self.active_alerts = {}
        self.alert_history = []
        self.alert_queue = []
        self.veterinarian_contacts = {}
        self.notification_settings = {
            'email_enabled': True,
            'sms_enabled': True,
            'alert_threshold_response_minutes': 15
        }
    
    def generate_alert(self, alert_type: AlertType, severity: AlertSeverity,
                      animal_id: str, message: str, data: Dict = None) -> Alert:
        """Generate and queue an alert"""
        alert = Alert(alert_type, severity, animal_id, message, data or {})
        
        # Add to queue based on severity
        self.alert_queue.append(alert)
        self.alert_queue.sort(key=lambda x: self._severity_rank(x.severity), reverse=True)
        
        # Store as active alert
        if severity in [AlertSeverity.HIGH, AlertSeverity.CRITICAL]:
            self.active_alerts[alert.alert_id] = alert
        
        # Add to history
        self.alert_history.append(alert)
        
        return alert
    
    def _severity_rank(self, severity: AlertSeverity) -> int:
        rank_map = {
            AlertSeverity.LOW: 1,
            AlertSeverity.MEDIUM: 2,
            AlertSeverity.HIGH: 3,
            AlertSeverity.CRITICAL: 4
        }
        return rank_map.get(severity, 0)
    
    def send_notification(self, alert: Alert, recipient: str = None) -> Dict:
        """Send alert notification"""
        notification = {
            'alert_id': alert.alert_id,
            'status': 'sent',
            'timestamp': datetime.now().isoformat(),
            'method': []
        }
        
        # Email notification
        if self.notification_settings['email_enabled']:
            email_result = self._send_email(alert, recipient)
            notification['method'].append({'email': email_result})
        
        # SMS for critical alerts
        if self.notification_settings['sms_enabled'] and alert.severity == AlertSeverity.CRITICAL:
            sms_result = self._send_sms(alert, recipient)
            notification['method'].append({'sms': sms_result})
        
        # Dashboard notification
        dashboard_result = self._send_dashboard_notification(alert)
        notification['method'].append({'dashboard': dashboard_result})
        
        return notification
    
    def _send_email(self, alert: Alert, recipient: str) -> Dict:
        """Simulate email send"""
        email_subject = f"🚨 [{alert.severity.value}] {alert.alert_type.value} - Animal {alert.animal_id}"
        email_body = f"""
        Alert ID: {alert.alert_id}
        Severity: {alert.severity.value}
        Type: {alert.alert_type.value}
        Animal: {alert.animal_id}
        Time: {alert.timestamp}
        
        Message: {alert.message}
        
        Data: {alert.data}
        
        Recommended Actions:
        - Monitor the animal closely
        - Consult with veterinarian if needed
        - Document all observations
        """
        
        return {
            'status': 'sent',
            'recipient': recipient or 'default@farm.com',
            'subject': email_subject
        }
    
    def _send_sms(self, alert: Alert, recipient: str) -> Dict:
        """Simulate SMS send"""
        sms_message = f"🚨 CRITICAL: {alert.alert_type.value} for animal {alert.animal_id}. {alert.message}"
        
        return {
            'status': 'sent',
            'recipient': recipient or '+216-xxx-xxx-xxxx',
            'message': sms_message
        }
    
    def _send_dashboard_notification(self, alert: Alert) -> Dict:
        """Send to dashboard"""
        return {
            'status': 'sent',
            'alert_id': alert.alert_id,
            'visible_on_dashboard': True
        }
    
    def acknowledge_alert(self, alert_id: str, notes: str = None) -> Dict:
        """Acknowledge an alert"""
        if alert_id in self.active_alerts:
            alert = self.active_alerts[alert_id]
            alert.acknowledged = True
            if notes:
                alert.actions_taken.append({
                    'timestamp': datetime.now().isoformat(),
                    'action': notes
                })
            
            return {
                'status': 'acknowledged',
                'alert_id': alert_id,
                'timestamp': datetime.now().isoformat()
            }
        
        return {'error': 'Alert not found'}
    
    def get_pending_alerts(self, severity_filter: AlertSeverity = None) -> List[Dict]:
        """Get pending alerts"""
        pending = [alert for alert in self.alert_queue if not alert.acknowledged]
        
        if severity_filter:
            pending = [alert for alert in pending if alert.severity == severity_filter]
        
        return [alert.to_dict() for alert in pending]
    
    def get_alert_history(self, animal_id: str = None, days: int = 7) -> List[Dict]:
        """Get alert history"""
        cutoff_date = datetime.now() - timedelta(days=days)
        history = [alert for alert in self.alert_history 
                  if alert.timestamp > cutoff_date]
        
        if animal_id:
            history = [alert for alert in history if alert.animal_id == animal_id]
        
        return [alert.to_dict() for alert in history]
    
    def get_alert_statistics(self) -> Dict:
        """Get alert statistics"""
        total_alerts = len(self.alert_history)
        
        severity_counts = {
            'critical': sum(1 for a in self.alert_history if a.severity == AlertSeverity.CRITICAL),
            'high': sum(1 for a in self.alert_history if a.severity == AlertSeverity.HIGH),
            'medium': sum(1 for a in self.alert_history if a.severity == AlertSeverity.MEDIUM),
            'low': sum(1 for a in self.alert_history if a.severity == AlertSeverity.LOW)
        }
        
        type_counts = {}
        for alert in self.alert_history:
            alert_type = alert.alert_type.value
            type_counts[alert_type] = type_counts.get(alert_type, 0) + 1
        
        return {
            'total_alerts': total_alerts,
            'by_severity': severity_counts,
            'by_type': type_counts,
            'active_alerts': len(self.active_alerts),
            'acknowledged_rate': (sum(1 for a in self.alert_history if a.acknowledged) / max(1, total_alerts)) * 100
        }
    
    def track_alert_response_time(self, alert_id: str) -> Dict:
        """Track response time to alert"""
        for alert in self.alert_history:
            if alert.alert_id == alert_id:
                if alert.acknowledged:
                    response_time = (alert.actions_taken[0]['timestamp'] if alert.actions_taken else None)
                    time_diff = datetime.fromisoformat(response_time) - alert.timestamp if response_time else None
                    
                    return {
                        'alert_id': alert_id,
                        'generated_at': alert.timestamp.isoformat(),
                        'acknowledged_at': response_time,
                        'response_time_minutes': time_diff.total_seconds() / 60 if time_diff else None,
                        'met_threshold': time_diff.total_seconds() / 60 <= self.notification_settings['alert_threshold_response_minutes'] if time_diff else None
                    }
        
        return {'error': 'Alert not found'}

# ============================================================================
# MAIN INTEGRATED SYSTEM
# ============================================================================

class LivestockHealthAgent:
    """Complete integrated livestock health monitoring system"""
    
    def __init__(self):
        self.health_monitor = HealthMonitor()
        self.disease_detector = DiseaseDetector()
        self.behavioral_analyzer = BehavioralAnalyzer()
        self.nutrition_optimizer = NutritionOptimizer()
        self.alert_system = AlertSystem()
    
    def process_animal_data(self, animal_id: str, data: Dict) -> Dict:
        """
        Process complete animal data and generate comprehensive report
        """
        species = data.get('species', 'cattle')
        
        # Health assessment
        vital_signs = VitalSigns(
            animal_id=animal_id,
            timestamp=data['timestamp'],
            body_temperature=data['body_temperature'],
            heart_rate=data['heart_rate'],
            respiratory_rate=data['respiratory_rate'],
            body_condition_score=data['body_condition_score'],
            weight=data['weight']
        )
        
        health_status, confidence = self.health_monitor.predict_health_status(
            vital_signs, species=species
        )
        
        # Disease detection
        clinical_signs = data.get('clinical_signs', {})
        diseases = self.disease_detector.detect_disease(vital_signs, clinical_signs, species)
        
        # Behavioral analysis
        behavior_score = self.behavioral_analyzer.generate_behavior_score(animal_id)
        anomalies = self.behavioral_analyzer.detect_anomalies(animal_id)
        
        # Nutrition assessment
        animal_data = {
            'animal_id': animal_id,
            'species': species,
            'weight': data['weight'],
            'stage': data.get('stage', 'maintenance'),
            'milk_production_liters': data.get('milk_production', 0)
        }
        nutrition_recommendation = self.nutrition_optimizer.recommend_diet(animal_data)
        
        # Generate alerts
        alerts_generated = []
        
        if health_status.value in ['Poor', 'Critical']:
            alert = self.alert_system.generate_alert(
                AlertType.HEALTH_WARNING if health_status.value == 'Poor' else AlertType.CRITICAL_EMERGENCY,
                AlertSeverity.HIGH if health_status.value == 'Poor' else AlertSeverity.CRITICAL,
                animal_id,
                f"Health status: {health_status.value}",
                vital_signs.to_dict()
            )
            alerts_generated.append(alert)
        
        if diseases:
            for disease_name, probability in diseases:
                severity = AlertSeverity.HIGH if probability > 0.7 else AlertSeverity.MEDIUM
                alert = self.alert_system.generate_alert(
                    AlertType.DISEASE_ALERT,
                    severity,
                    animal_id,
                    f"Possible {disease_name} detected",
                    {'disease': disease_name, 'probability': probability}
                )
                alerts_generated.append(alert)
        
        if behavior_score['status'] == 'Critical':
            alert = self.alert_system.generate_alert(
                AlertType.BEHAVIOR_ANOMALY,
                AlertSeverity.HIGH,
                animal_id,
                f"Behavioral anomalies detected: {', '.join(behavior_score['issues'])}",
                behavior_score
            )
            alerts_generated.append(alert)
        
        # Comprehensive report
        report = {
            'animal_id': animal_id,
            'timestamp': data['timestamp'],
            'health_assessment': {
                'status': health_status.value,
                'confidence': confidence,
                'vital_signs': vital_signs.to_dict()
            },
            'disease_assessment': {
                'detected_diseases': diseases,
                'disease_details': [
                    self.disease_detector.get_disease_details(disease[0])
                    for disease in diseases[:3]
                ]
            },
            'behavioral_assessment': {
                'behavior_score': behavior_score['behavior_score'],
                'status': behavior_score['status'],
                'anomalies': anomalies,
                'issues': behavior_score['issues']
            },
            'nutrition_assessment': nutrition_recommendation,
            'alerts': [alert.to_dict() for alert in alerts_generated],
            'alert_statistics': self.alert_system.get_alert_statistics(),
            'recommendations': self._generate_comprehensive_recommendations(
                health_status, diseases, behavior_score, anomalies
            )
        }
        
        return report
    
    def _generate_comprehensive_recommendations(self, health_status, diseases, 
                                               behavior_score, anomalies) -> List[str]:
        """Generate comprehensive recommendations"""
        recommendations = []
        
        # Health-based
        if health_status.value in ['Poor', 'Critical']:
            recommendations.append("🚨 URGENT: Consult veterinarian immediately")
        elif health_status.value == 'Moderate':
            recommendations.append("⚠️ Schedule veterinary checkup within 48 hours")
        
        # Disease-based
        if diseases:
            recommendations.append(f"🦠 Monitor for symptoms of: {', '.join([d[0] for d in diseases[:2]])}")
        
        # Behavior-based
        if behavior_score['status'] == 'Critical':
            recommendations.extend([
                "👀 Increase monitoring frequency",
                "🏥 Isolate from herd if showing signs of illness"
            ])
        
        # Anomaly-based
        for anomaly in anomalies:
            recommendations.append(f"📌 {anomaly['action']}")
        
        recommendations.append("✅ Continue regular health monitoring")
        
        return recommendations