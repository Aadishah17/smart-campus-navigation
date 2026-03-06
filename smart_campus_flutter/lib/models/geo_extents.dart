import 'campus_location.dart';

class GeoExtents {
  const GeoExtents({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory GeoExtents.fromLocations(List<CampusLocation> locations) {
    if (locations.isEmpty) {
      return const GeoExtents(
        minLat: 23.035,
        maxLat: 23.039,
        minLng: 72.55,
        maxLng: 72.555,
      );
    }

    var minLat = locations.first.lat;
    var maxLat = locations.first.lat;
    var minLng = locations.first.lng;
    var maxLng = locations.first.lng;

    for (final location in locations) {
      if (location.lat < minLat) {
        minLat = location.lat;
      }
      if (location.lat > maxLat) {
        maxLat = location.lat;
      }
      if (location.lng < minLng) {
        minLng = location.lng;
      }
      if (location.lng > maxLng) {
        maxLng = location.lng;
      }
    }

    if ((maxLat - minLat).abs() < 0.000001) {
      maxLat += 0.0004;
      minLat -= 0.0004;
    }
    if ((maxLng - minLng).abs() < 0.000001) {
      maxLng += 0.0004;
      minLng -= 0.0004;
    }

    return GeoExtents(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool get isValid => maxLat > minLat && maxLng > minLng;
}
