import 'campus_location.dart';

class RouteResult {
  const RouteResult({
    required this.source,
    required this.destination,
    required this.path,
    required this.totalDistanceMeters,
    required this.totalDistanceKm,
    required this.estimatedWalkMinutes,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final pathRaw = (json['path'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return RouteResult(
      source: CampusLocation.fromJson(
        (json['source'] as Map<String, dynamic>?) ?? const {},
      ),
      destination: CampusLocation.fromJson(
        (json['destination'] as Map<String, dynamic>?) ?? const {},
      ),
      path: pathRaw.map(CampusLocation.fromJson).toList(),
      totalDistanceMeters: _asDouble(json['totalDistanceMeters']),
      totalDistanceKm: _asDouble(json['totalDistanceKm']),
      estimatedWalkMinutes: _asInt(json['estimatedWalkMinutes']),
    );
  }

  final CampusLocation source;
  final CampusLocation destination;
  final List<CampusLocation> path;
  final double totalDistanceMeters;
  final double totalDistanceKm;
  final int estimatedWalkMinutes;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
