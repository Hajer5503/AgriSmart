import '../models/plant_analysis.dart';
import 'api_service.dart';

class PlantAnalysisService {
  final ApiService _apiService = ApiService();

  // Analyser une photo de plante
  Future<PlantAnalysis> analyzePlant(String imagePath, int userId) async {
    try {
      // Upload l'image et obtenir l'analyse
      final response = await _apiService.uploadFile(
        '/plant-analysis/analyze',
        imagePath,
      );

      return PlantAnalysis.fromJson({
        ...response.data,
        'user_id': userId,
        'image_path': imagePath,
      });
    } catch (e) {
      throw Exception('Erreur d\'analyse: ${e.toString()}');
    }
  }

  // Obtenir l'historique des analyses
  Future<List<PlantAnalysis>> getHistory(int userId) async {
    try {
      final response = await _apiService.get('/plant-analysis/history/$userId');
      return (response.data as List)
          .map((json) => PlantAnalysis.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur de chargement: ${e.toString()}');
    }
  }

  // Obtenir une analyse spécifique
  Future<PlantAnalysis> getAnalysis(int id) async {
    try {
      final response = await _apiService.get('/plant-analysis/$id');
      return PlantAnalysis.fromJson(response.data);
    } catch (e) {
      throw Exception('Erreur de chargement: ${e.toString()}');
    }
  }
}
