import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
class NutritionOptimizer:
    def __init__(self):
        self.nutritional_requirements = {
            'cattle': {
                'growing': {'energy_mcal': 8.5, 'protein_percent': 15, 'calcium_percent': 0.6},
                'lactating': {'energy_mcal': 18, 'protein_percent': 16, 'calcium_percent': 0.8},
                'maintenance': {'energy_mcal': 8, 'protein_percent': 10, 'calcium_percent': 0.4}
            },
            'sheep': {
                'growing': {'energy_mcal': 2.5, 'protein_percent': 14, 'calcium_percent': 0.5},
                'lactating': {'energy_mcal': 3.5, 'protein_percent': 15, 'calcium_percent': 0.7},
                'maintenance': {'energy_mcal': 2, 'protein_percent': 9, 'calcium_percent': 0.3}
            }
        }
        
        self.feed_database = {
            'alfalfa_hay': {'energy_mcal': 1.8, 'protein_percent': 18, 'cost_per_kg': 0.15},
            'timothy_hay': {'energy_mcal': 1.6, 'protein_percent': 10, 'cost_per_kg': 0.12},
            'corn': {'energy_mcal': 3.2, 'protein_percent': 9, 'cost_per_kg': 0.25},
            'soybean_meal': {'energy_mcal': 2.2, 'protein_percent': 50, 'cost_per_kg': 0.40},
            'barley': {'energy_mcal': 2.8, 'protein_percent': 12, 'cost_per_kg': 0.20},
            'oats': {'energy_mcal': 2.4, 'protein_percent': 11, 'cost_per_kg': 0.18}
        }
    
    def calculate_requirements(self, animal_data: Dict) -> Dict:
        """
        Calculate nutritional requirements
        animal_data: {species, weight, stage, milk_production}
        """
        species = animal_data['species']
        stage = animal_data['stage']
        weight = animal_data['weight']
        
        base_requirements = self.nutritional_requirements[species][stage]
        
        # Adjust for weight
        weight_factor = weight / 500  # Normalize to 500kg animal
        
        adjusted_requirements = {
            'energy_mcal': base_requirements['energy_mcal'] * weight_factor,
            'protein_kg': (base_requirements['protein_percent'] / 100) * (weight * 0.02),
            'calcium_kg': (base_requirements['calcium_percent'] / 100) * (weight * 0.02)
        }
        
        # Add extra for milk production if applicable
        if 'milk_production_liters' in animal_data:
            milk = animal_data['milk_production_liters']
            adjusted_requirements['energy_mcal'] += milk * 0.65
            adjusted_requirements['protein_kg'] += milk * 0.035
        
        return adjusted_requirements
    
    def optimize_feed(self, requirements: Dict, budget: float = None) -> Dict:
        """
        Optimize feed mix to meet requirements at lowest cost
        """
        best_mix = None
        min_cost = float('inf')
        
        feed_combinations = [
            {'alfalfa_hay': 0.5, 'timothy_hay': 0.3, 'corn': 0.2},
            {'timothy_hay': 0.6, 'barley': 0.4},
            {'alfalfa_hay': 0.4, 'soybean_meal': 0.1, 'corn': 0.5},
            {'timothy_hay': 0.5, 'oats': 0.3, 'soybean_meal': 0.2}
        ]
        
        for combination in feed_combinations:
            total_energy = 0
            total_protein = 0
            total_cost = 0
            total_weight = 0
            
            # Assume 10 kg total daily feed
            for feed, proportion in combination.items():
                if feed not in self.feed_database:
                    continue
                
                feed_amount = 10 * proportion
                feed_data = self.feed_database[feed]
                
                total_energy += feed_data['energy_mcal'] * feed_amount
                total_protein += feed_data['protein_percent'] * feed_amount
                total_cost += feed_data['cost_per_kg'] * feed_amount
                total_weight += feed_amount
            
            # Check if requirements are met
            if (total_energy >= requirements['energy_mcal'] * 0.95 and
                total_protein >= requirements['protein_kg'] * 0.95):
                
                if budget is None or total_cost <= budget:
                    if total_cost < min_cost:
                        min_cost = total_cost
                        best_mix = {
                            'composition': combination,
                            'daily_amount_kg': total_weight,
                            'energy_provided_mcal': total_energy,
                            'protein_provided_kg': total_protein,
                            'daily_cost': total_cost
                        }
        
        return best_mix or {'error': 'No suitable feed mix found'}
    
    def recommend_diet(self, animal_data: Dict, budget: float = None) -> Dict:
        """Generate complete diet recommendation"""
        requirements = self.calculate_requirements(animal_data)
        optimal_feed = self.optimize_feed(requirements, budget)
        
        return {
            'animal_id': animal_data.get('animal_id', 'Unknown'),
            'species': animal_data['species'],
            'stage': animal_data['stage'],
            'weight_kg': animal_data['weight'],
            'requirements': requirements,
            'recommended_feed_mix': optimal_feed,
            'feeding_schedule': self._generate_feeding_schedule(optimal_feed),
            'monitoring_points': [
                '📌 Track daily intake',
                '📌 Monitor body weight weekly',
                '📌 Assess body condition every 2 weeks',
                '📌 Check digestive health daily'
            ]
        }
    
    def _generate_feeding_schedule(self, feed_mix: Dict) -> List[Dict]:
        """Generate daily feeding schedule"""
        if 'error' in feed_mix:
            return []
        
        total_daily = feed_mix['daily_amount_kg']
        
        return [
            {'time': '06:00', 'amount_kg': total_daily * 0.35, 'meal': 'Morning'},
            {'time': '12:00', 'amount_kg': total_daily * 0.30, 'meal': 'Midday'},
            {'time': '18:00', 'amount_kg': total_daily * 0.35, 'meal': 'Evening'}
        ]
    
    def calculate_feed_efficiency(self, animal_data: Dict, feed_consumed: float, 
                                 weight_gain: float) -> Dict:
        """Calculate feed conversion efficiency"""
        feed_efficiency = weight_gain / feed_consumed if feed_consumed > 0 else 0
        
        # Species-specific targets
        targets = {
            'cattle': 0.25,  # 250g gain per kg feed
            'sheep': 0.20,
            'goat': 0.22,
            'pig': 0.30
        }
        
        target = targets.get(animal_data['species'], 0.25)
        efficiency_percent = (feed_efficiency / target) * 100
        
        return {
            'feed_efficiency': feed_efficiency,
            'efficiency_vs_target_percent': efficiency_percent,
            'status': 'Excellent' if efficiency_percent > 90 else 'Good' if efficiency_percent > 75 else 'Poor',
            'recommendations': self._feed_efficiency_recommendations(efficiency_percent)
        }
    
    def _feed_efficiency_recommendations(self, efficiency_percent: float) -> List[str]:
        recommendations = []
        
        if efficiency_percent < 75:
            recommendations.append("❌ Feed efficiency below target")
            recommendations.append("📌 Check water availability")
            recommendations.append("📌 Review feed quality")
            recommendations.append("📌 Assess for parasites or illness")
        elif efficiency_percent < 90:
            recommendations.append("⚠️ Feed efficiency slightly below target")
            recommendations.append("📌 Optimize feed composition")
        else:
            recommendations.append("✅ Feed efficiency excellent")
        
        return recommendations