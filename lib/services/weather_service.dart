import 'api_service.dart';

class WeatherData {
  final String city;
  final int temp;
  final int feelsLike;
  final int humidity;
  final String description;
  final String icon;
  final int wind;

  WeatherData({
    required this.city,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.wind,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        city: json['city'] ?? '',
        temp: json['temp'] ?? 0,
        feelsLike: json['feels_like'] ?? 0,
        humidity: json['humidity'] ?? 0,
        description: json['description'] ?? '',
        icon: json['icon'] ?? '01d',
        wind: json['wind'] ?? 0,
      );

  // URL de l'icône météo OpenWeatherMap
  String get iconUrl => 'https://openweathermap.org/img/wn/${icon}@2x.png';
}

class WeatherService {
  final ApiService _api = ApiService();
  WeatherData? _cached;
  DateTime? _lastFetch;

  Future<WeatherData> getWeather({String city = 'Tunis'}) async {
    // Cache de 10 minutes
    if (_cached != null && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 10) {
      return _cached!;
    }
    final response = await _api.get('/weather', queryParameters: {'city': city});
    _cached = WeatherData.fromJson(response.data);
    _lastFetch = DateTime.now();
    return _cached!;
  }
}