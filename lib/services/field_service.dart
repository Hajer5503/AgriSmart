import 'api_service.dart';

// ─── Modèle Farm (adapté à ta BD : owner_id) ─────────────
class Farm {
  final int id;
  final int ownerId;
  final String name;
  final String? location;
  final double? areaHectares;
  final String? farmType;

  Farm({
    required this.id,
    required this.ownerId,
    required this.name,
    this.location,
    this.areaHectares,
    this.farmType,
  });

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json['id'],
        ownerId: json['owner_id'] ?? json['user_id'] ?? 0,
        name: json['name'] ?? '',
        location: json['location'],
        areaHectares: json['area_hectares'] != null
            ? double.tryParse(json['area_hectares'].toString())
            : null,
        farmType: json['farm_type'],
      );
}

// ─── Modèle Field (parcelle — ta table "fields") ─────────
class Field {
  final int id;
  final int farmId;
  final String name;
  final double? areaHectares;
  final String? soilType;
  final String? currentCrop;
  final String? farmName; // jointure

  Field({
    required this.id,
    required this.farmId,
    required this.name,
    this.areaHectares,
    this.soilType,
    this.currentCrop,
    this.farmName,
  });

  factory Field.fromJson(Map<String, dynamic> json) => Field(
        id: json['id'],
        farmId: json['farm_id'],
        name: json['name'] ?? '',
        areaHectares: json['area_hectares'] != null
            ? double.tryParse(json['area_hectares'].toString())
            : null,
        soilType: json['soil_type'],
        currentCrop: json['current_crop'],
        farmName: json['farm_name'],
      );

  // Statut calculé localement selon la culture
  String get status {
    if (currentCrop == null || currentCrop!.isEmpty) return 'Vide';
    return 'En culture';
  }

  double get healthScore {
    // Score fictif local — remplaceable par vraie donnée IoT
    return currentCrop != null ? 0.85 : 0.4;
  }
}

// ─── Service ─────────────────────────────────────────────
class FieldService {
  final ApiService _api = ApiService();

  // Fermes de l'utilisateur
  Future<List<Farm>> getFarms() async {
    final r = await _api.get('/farms');
    return (r.data as List).map((e) => Farm.fromJson(e)).toList();
  }

  Future<Farm> createFarm({
    required String name,
    String? location,
    double? areaHectares,
    String? farmType,
  }) async {
    final r = await _api.post('/farms', data: {
      'name': name,
      'location': location,
      'area_hectares': areaHectares,
      'farm_type': farmType,
    });
    return Farm.fromJson(r.data);
  }

  Future<void> deleteFarm(int farmId) async {
    await _api.delete('/farms/$farmId');
  }

  // Parcelles (fields)
  Future<List<Field>> getFields({int? farmId}) async {
    final params = farmId != null ? {'farm_id': farmId} : null;
    final r = await _api.get('/fields', queryParameters: params);
    return (r.data as List).map((e) => Field.fromJson(e)).toList();
  }

  Future<Field> createField({
    required int farmId,
    required String name,
    double? areaHectares,
    String? soilType,
    String? currentCrop,
  }) async {
    final r = await _api.post('/fields', data: {
      'farm_id': farmId,
      'name': name,
      'area_hectares': areaHectares,
      'soil_type': soilType,
      'current_crop': currentCrop,
    });
    return Field.fromJson(r.data);
  }

  Future<void> deleteField(int fieldId) async {
    await _api.delete('/fields/$fieldId');
  }
}