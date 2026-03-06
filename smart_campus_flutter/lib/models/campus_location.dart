class CampusLocation {
  const CampusLocation({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.aliases,
    required this.lat,
    required this.lng,
    required this.guideX,
    required this.guideY,
    required this.facilities,
    required this.connections,
    this.distanceMeters,
  });

  factory CampusLocation.fromJson(Map<String, dynamic> json) {
    return CampusLocation(
      id: _asString(json['id'] ?? json['_id']),
      name: _asString(json['name']),
      type: _asString(json['type']),
      description: _asString(json['description']),
      aliases: _asStringList(json['aliases']),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      guideX: _asNullableDouble(json['guideX']),
      guideY: _asNullableDouble(json['guideY']),
      facilities: _asStringList(json['facilities']),
      connections: _asStringList(json['connections']),
      distanceMeters: json['distanceMeters'] == null
          ? null
          : _asDouble(json['distanceMeters']),
    );
  }

  final String id;
  final String name;
  final String type;
  final String description;
  final List<String> aliases;
  final double lat;
  final double lng;
  final double? guideX;
  final double? guideY;
  final List<String> facilities;
  final List<String> connections;
  final double? distanceMeters;

  bool get hasGuideAnchor => guideX != null && guideY != null;
}

String _asString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
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

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is List<dynamic>) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}
