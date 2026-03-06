import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/campus_location.dart';

const double guideMapCanvasWidth = 1765;
const double guideMapCanvasHeight = 2491;

const Size guideMapCanvasSize = Size(guideMapCanvasWidth, guideMapCanvasHeight);

final LatLngBounds guideMapBounds = LatLngBounds(
  const LatLng(-guideMapCanvasHeight, 0),
  const LatLng(0, guideMapCanvasWidth),
);

class GuideMapProjection {
  GuideMapProjection(this.locations);

  final List<CampusLocation> locations;

  static const Rect _fallbackViewport = Rect.fromLTWH(180, 160, 1380, 1450);

  Offset projectLocation(CampusLocation location) {
    if (location.hasGuideAnchor) {
      return Offset(location.guideX!, location.guideY!);
    }
    return projectPosition(location.lat, location.lng);
  }

  LatLng mapPointForLocation(CampusLocation location) =>
      toMapPoint(projectLocation(location));

  LatLng mapPointForPosition(double lat, double lng) =>
      toMapPoint(projectPosition(lat, lng));

  Offset projectPosition(double lat, double lng) {
    final anchoredLocations =
        locations
            .where((location) => location.hasGuideAnchor)
            .map(
              (location) => (
                offset: Offset(location.guideX!, location.guideY!),
                distanceMeters: const Distance().as(
                  LengthUnit.Meter,
                  LatLng(lat, lng),
                  LatLng(location.lat, location.lng),
                ),
              ),
            )
            .toList()
          ..sort(
            (left, right) =>
                left.distanceMeters.compareTo(right.distanceMeters),
          );

    if (anchoredLocations.length < 3) {
      return _fallbackProject(lat, lng);
    }

    if (anchoredLocations.first.distanceMeters <= 7) {
      return anchoredLocations.first.offset;
    }

    final nearest = anchoredLocations.take(
      math.min(4, anchoredLocations.length),
    );
    var weightSum = 0.0;
    var projectedX = 0.0;
    var projectedY = 0.0;

    for (final anchor in nearest) {
      final weight = 1 / math.pow(math.max(anchor.distanceMeters, 18), 1.35);
      final safeWeight = weight.toDouble();
      weightSum += safeWeight;
      projectedX += anchor.offset.dx * safeWeight;
      projectedY += anchor.offset.dy * safeWeight;
    }

    if (weightSum == 0) {
      return _fallbackProject(lat, lng);
    }

    return _clamp(Offset(projectedX / weightSum, projectedY / weightSum));
  }

  List<List<LatLng>> buildNetworkPolylines() {
    final locationById = {
      for (final location in locations) location.id: location,
    };
    final seen = <String>{};
    final polylines = <List<LatLng>>[];

    for (final location in locations) {
      for (final targetId in location.connections) {
        final key = _edgeKey(location.id, targetId);
        if (!seen.add(key)) {
          continue;
        }

        final target = locationById[targetId];
        if (target == null) {
          continue;
        }

        polylines.add(buildSegment(location, target));
      }
    }

    return polylines;
  }

  List<LatLng> routeMapPoints(List<CampusLocation> routePath) {
    if (routePath.isEmpty) {
      return const [];
    }

    if (routePath.length == 1) {
      return [mapPointForLocation(routePath.first)];
    }

    final merged = <LatLng>[];
    for (var index = 0; index < routePath.length - 1; index++) {
      final segment = buildSegment(routePath[index], routePath[index + 1]);
      if (segment.isEmpty) {
        continue;
      }

      if (merged.isNotEmpty && merged.last == segment.first) {
        merged.addAll(segment.skip(1));
      } else {
        merged.addAll(segment);
      }
    }

    return merged;
  }

  List<LatLng> buildSegment(CampusLocation from, CampusLocation to) {
    return [mapPointForLocation(from), mapPointForLocation(to)];
  }

  LatLng toMapPoint(Offset offset) => LatLng(-offset.dy, offset.dx);

  Offset _fallbackProject(double lat, double lng) {
    if (locations.isEmpty) {
      return const Offset(882.5, 980);
    }

    var minLat = locations.first.lat;
    var maxLat = locations.first.lat;
    var minLng = locations.first.lng;
    var maxLng = locations.first.lng;

    for (final location in locations) {
      minLat = math.min(minLat, location.lat);
      maxLat = math.max(maxLat, location.lat);
      minLng = math.min(minLng, location.lng);
      maxLng = math.max(maxLng, location.lng);
    }

    final lngRange = math.max(maxLng - minLng, 0.00001);
    final latRange = math.max(maxLat - minLat, 0.00001);
    final xRatio = ((lng - minLng) / lngRange).clamp(0.0, 1.0);
    final yRatio = (1 - ((lat - minLat) / latRange)).clamp(0.0, 1.0);

    return _clamp(
      Offset(
        _fallbackViewport.left + (_fallbackViewport.width * xRatio),
        _fallbackViewport.top + (_fallbackViewport.height * yRatio),
      ),
    );
  }

  Offset _clamp(Offset offset) {
    return Offset(
      offset.dx.clamp(0.0, guideMapCanvasWidth),
      offset.dy.clamp(0.0, guideMapCanvasHeight),
    );
  }

  static String _edgeKey(String first, String second) {
    return first.compareTo(second) <= 0 ? '$first|$second' : '$second|$first';
  }
}
