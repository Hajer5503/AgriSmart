import 'api_service.dart';

class Farm {
  final int id;
  final int userId;
  final String name;
  final String? location;
  final double? areaHectares;
  final String? soilType;

  Farm({
    required this.id,
    required this.userId,
    required this.name,
    this.location,
    this.areaHectares,
    this.soilType,
  });

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
    id: json['id'],
    userId: json['user_id'],
    name: json['name'],
    location: json['location'],
    areaHectares: json['area_hectares'] != null
        ? double.tryParse(json['area_hectares'].toString())
        : null,
    soilType: json['soil_type'],
  );
}

class FarmService {
  final ApiService _api = ApiService();

  Future<List<Farm>> getFarms(int userId) async {
    final response = await _api.get('/farms', queryParameters: {'user_id': userId});
    return (response.data as List).map((e) => Farm.fromJson(e)).toList();
  }

  Future<Farm> createFarm({
    required int userId,
    required String name,
    String? location,
    double? areaHectares,
    String? soilType,
  }) async {
    final response = await _api.post('/farms', data: {
      'user_id': userId,
      'name': name,
      'location': location,
      'area_hectares': areaHectares,
      'soil_type': soilType,
    });
    return Farm.fromJson(response.data);
  }

  Future<void> deleteFarm(int farmId) async {
    await _api.delete('/farms/$farmId');
  }
}