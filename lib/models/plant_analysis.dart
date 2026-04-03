class PlantAnalysis {
  final int? id;
  final int userId;
  final String imagePath;
  final String? diagnosis;
  final double? confidence;
  final String? recommendations;
  final DateTime analyzedAt;

  PlantAnalysis({
    this.id,
    required this.userId,
    required this.imagePath,
    this.diagnosis,
    this.confidence,
    this.recommendations,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'image_path': imagePath,
      'diagnosis': diagnosis,
      'confidence': confidence,
      'recommendations': recommendations,
      'analyzed_at': analyzedAt.toIso8601String(),
    };
  }

  factory PlantAnalysis.fromJson(Map<String, dynamic> json) {
    return PlantAnalysis(
      id: json['id'],
      userId: json['user_id'],
      imagePath: json['image_path'],
      diagnosis: json['diagnosis'],
      confidence: json['confidence']?.toDouble(),
      recommendations: json['recommendations'],
      analyzedAt: DateTime.parse(json['analyzed_at']),
    );
  }
}
