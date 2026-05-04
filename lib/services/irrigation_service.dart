import 'api_service.dart';

class IrrigationResult {
  final double soilMoisture;
  final String status;
  final int recommendedMm;
  final List<int> availableActions;
  final String advice;
  final String source;
  final List<double> optimalBand;
  final Map<String, dynamic>? field;

  IrrigationResult({
    required this.soilMoisture,
    required this.status,
    required this.recommendedMm,
    required this.availableActions,
    required this.advice,
    required this.source,
    required this.optimalBand,
    this.field,
  });

  factory IrrigationResult.fromJson(Map<String, dynamic> json) {
    final band = (json['optimal_band'] as List?)?.cast<num>() ?? [0.208, 0.28];
    final actions = (json['available_actions_mm'] as List?)?.cast<num>().map((e) => e.toInt()).toList() ?? [0, 5, 10, 15, 20];
    return IrrigationResult(
      soilMoisture:    (json['soil_moisture'] as num?)?.toDouble() ?? 0.0,
      status:          json['status'] as String? ?? 'unknown',
      recommendedMm:   (json['recommended_irrigation_mm'] as num?)?.toInt() ?? 0,
      availableActions: actions,
      advice:          json['advice'] as String? ?? json['recommendation'] as String? ?? '',
      source:          json['source'] as String? ?? 'unknown',
      optimalBand:     band.map((e) => e.toDouble()).toList(),
      field:           json['field'] as Map<String, dynamic>?,
    );
  }

  bool get isOptimal => status == 'optimal' || status == 'surplus';
  String get statusLabel {
    switch (status) {
      case 'surplus':     return 'Sol saturé';
      case 'optimal':     return 'Optimal';
      case 'sous_optimal': return 'Légèrement bas';
      case 'faible':      return 'Stress hydrique';
      case 'critique':    return 'Critique';
      default:            return status;
    }
  }
}

class IrrigationService {
  final ApiService _api;
  IrrigationService(this._api);

  /// Appelle POST /api/agent/irrigation
  /// [soilMoisture] : valeur entre 0 et 1 (ex: 0.25 pour 25%)
  /// [fieldId] : ID de la parcelle (optionnel)
  /// [location] : ville pour la météo (optionnel, défaut Tunis)
  Future<IrrigationResult> getRecommendation({
    required double soilMoisture,
    int? fieldId,
    String? location,
  }) async {
    final response = await _api.post('/agent/irrigation', data: {
      'soil_moisture': soilMoisture,
      if (fieldId != null) 'field_id': fieldId,
      if (location != null) 'location': location,
    });
    return IrrigationResult.fromJson(response.data as Map<String, dynamic>);
  }
}
