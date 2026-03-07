import 'dart:math' as math;

import '../data/offline_campus_locations.dart';
import '../models/campus_location.dart';
import '../models/route_result.dart';

class CampusRouteLeg {
  const CampusRouteLeg({
    required this.from,
    required this.to,
    required this.distanceMeters,
  });

  final CampusLocation from;
  final CampusLocation to;
  final double distanceMeters;
}

class CampusNavigationEngine {
  static const String defaultCampusSourceId = 'entry-gate';
  static const double _earthRadiusMeters = 6371000;

  static List<CampusLocation> get bundledLocations => offlineCampusLocations;

  static CampusLocation? findById(List<CampusLocation> locations, String? id) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }

    final normalized = id.toLowerCase();
    for (final location in locations) {
      if (location.id == normalized) {
        return location;
      }
    }

    return null;
  }

  static CampusLocation? findNearestLocation(
    List<CampusLocation> locations, {
    required double lat,
    required double lng,
  }) {
    if (locations.isEmpty) {
      return null;
    }

    CampusLocation? nearest;
    var nearestMeters = double.infinity;

    for (final location in locations) {
      final candidateMeters = distanceMeters(
        lat,
        lng,
        location.lat,
        location.lng,
      );
      if (candidateMeters < nearestMeters) {
        nearestMeters = candidateMeters;
        nearest = location;
      }
    }

    return nearest;
  }

  static List<CampusLocation> findNearbyLocations(
    List<CampusLocation> locations, {
    required double lat,
    required double lng,
    double radiusMeters = 1000,
    int limit = 8,
    bool Function(CampusLocation location)? predicate,
  }) {
    final filtered =
        locations
            .where((location) => predicate == null || predicate(location))
            .map(
              (location) => CampusLocation(
                id: location.id,
                name: location.name,
                type: location.type,
                description: location.description,
                aliases: location.aliases,
                lat: location.lat,
                lng: location.lng,
                guideX: location.guideX,
                guideY: location.guideY,
                facilities: location.facilities,
                connections: location.connections,
                distanceMeters: distanceMeters(
                  lat,
                  lng,
                  location.lat,
                  location.lng,
                ),
              ),
            )
            .where((location) => location.distanceMeters! <= radiusMeters)
            .toList()
          ..sort(
            (left, right) =>
                left.distanceMeters!.compareTo(right.distanceMeters!),
          );

    return filtered.take(limit).toList(growable: false);
  }

  static CampusLocation campusAnchor(
    List<CampusLocation> locations, {
    String preferredId = defaultCampusSourceId,
  }) {
    return findById(locations, preferredId) ??
        (locations.isNotEmpty ? locations.first : bundledLocations.first);
  }

  static ({double lat, double lng}) campusCenter(
    List<CampusLocation> locations,
  ) {
    final source = locations.isEmpty ? bundledLocations : locations;
    var latTotal = 0.0;
    var lngTotal = 0.0;

    for (final location in source) {
      latTotal += location.lat;
      lngTotal += location.lng;
    }

    return (lat: latTotal / source.length, lng: lngTotal / source.length);
  }

  static bool isOnCampus(
    List<CampusLocation> locations, {
    required double lat,
    required double lng,
    double paddingMeters = 220,
  }) {
    final source = locations.isEmpty ? bundledLocations : locations;
    var minLat = source.first.lat;
    var maxLat = source.first.lat;
    var minLng = source.first.lng;
    var maxLng = source.first.lng;

    for (final location in source.skip(1)) {
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

    final midLatRadians = ((minLat + maxLat) / 2) * (3.141592653589793 / 180);
    final latPadding = paddingMeters / 111320;
    final lngPadding =
        paddingMeters / (111320 * midLatRadians.cos().abs().clamp(0.2, 1.0));

    return lat >= (minLat - latPadding) &&
        lat <= (maxLat + latPadding) &&
        lng >= (minLng - lngPadding) &&
        lng <= (maxLng + lngPadding);
  }

  static RouteResult? calculateRoute({
    required List<CampusLocation> locations,
    required String destinationId,
    String? sourceId,
    double? sourceLat,
    double? sourceLng,
  }) {
    final sourceLocations = locations.isEmpty ? bundledLocations : locations;
    final locationById = {
      for (final location in sourceLocations) location.id: location,
    };
    final destination = locationById[destinationId.toLowerCase()];
    if (destination == null) {
      return null;
    }

    var resolvedSourceId = sourceId?.toLowerCase();
    if (sourceLat != null && sourceLng != null) {
      final nearest = findNearestLocation(
        sourceLocations,
        lat: sourceLat,
        lng: sourceLng,
      );
      resolvedSourceId = nearest?.id;
    }
    resolvedSourceId ??= campusAnchor(sourceLocations).id;

    final source = locationById[resolvedSourceId];
    if (source == null) {
      return null;
    }

    final graph = _buildGraph(sourceLocations);
    final result = _runDijkstra(graph, source.id, destination.id);
    if (result == null) {
      return null;
    }

    final path = result.pathIds
        .map((id) => locationById[id])
        .whereType<CampusLocation>()
        .toList(growable: false);

    return RouteResult(
      source: source,
      destination: destination,
      path: path,
      totalDistanceMeters: result.totalDistanceMeters,
      totalDistanceKm: result.totalDistanceMeters / 1000,
      estimatedWalkMinutes: _estimateWalkMinutes(result.totalDistanceMeters),
    );
  }

  static List<CampusRouteLeg> buildRouteLegs(List<CampusLocation> path) {
    if (path.length < 2) {
      return const [];
    }

    final legs = <CampusRouteLeg>[];
    for (var index = 0; index < path.length - 1; index++) {
      legs.add(
        CampusRouteLeg(
          from: path[index],
          to: path[index + 1],
          distanceMeters: distanceMeters(
            path[index].lat,
            path[index].lng,
            path[index + 1].lat,
            path[index + 1].lng,
          ),
        ),
      );
    }
    return legs;
  }

  static String assistantReply({
    required List<CampusLocation> locations,
    required String message,
    double? userLat,
    double? userLng,
    bool userOnCampus = true,
  }) {
    final sourceLocations = locations.isEmpty ? bundledLocations : locations;
    final safeMessage = message.trim();
    final lowerMessage = safeMessage.toLowerCase();
    final anchor = campusAnchor(sourceLocations);
    final referenceLat = userOnCampus && userLat != null ? userLat : anchor.lat;
    final referenceLng = userOnCampus && userLng != null ? userLng : anchor.lng;
    final nearby = findNearbyLocations(
      sourceLocations,
      lat: referenceLat,
      lng: referenceLng,
      radiusMeters: 1200,
      limit: 5,
    );
    final nearest = nearby.isEmpty ? null : nearby.first;
    final mentionedLocation = _findMentionedLocation(
      sourceLocations,
      lowerMessage,
    );

    if (safeMessage.isEmpty) {
      return 'Ask me about nearby places, route planning, libraries, hostels, or food courts on the Parul University campus.';
    }

    if (!userOnCampus &&
        (lowerMessage.contains('where am i') ||
            lowerMessage.contains('my location'))) {
      return 'Your GPS appears outside the mapped Parul University campus, so I am keeping navigation focused near ${anchor.name}.';
    }

    if (lowerMessage.contains('where am i') ||
        lowerMessage.contains('my location')) {
      if (nearest == null) {
        return 'I could not resolve your current campus position yet. I am keeping the map centered on Parul University.';
      }
      return 'You are closest to ${nearest.name} (${_formatDistance(nearest.distanceMeters ?? 0)} away).';
    }

    if (lowerMessage.contains('nearby') || lowerMessage.contains('nearest')) {
      if (nearby.isEmpty) {
        return 'I do not have nearby campus matches right now.';
      }
      final summary = nearby
          .take(3)
          .map(
            (location) =>
                '${location.name} (${_formatDistance(location.distanceMeters ?? 0)})',
          )
          .join(', ');
      return 'Closest campus places: $summary.';
    }

    if (mentionedLocation != null) {
      final facilities = mentionedLocation.facilities.isEmpty
          ? 'No facilities listed'
          : mentionedLocation.facilities.join(', ');
      return '${mentionedLocation.name}: ${mentionedLocation.description} Facilities: $facilities.';
    }

    if (lowerMessage.contains('food') ||
        lowerMessage.contains('canteen') ||
        lowerMessage.contains('coffee')) {
      final spot = _bestMatchingLocation(
        sourceLocations,
        lat: referenceLat,
        lng: referenceLng,
        predicate: (location) => location.type == 'dining',
      );
      return spot == null
          ? 'I could not find a dining destination right now.'
          : 'Nearest dining option is ${spot.name} (${_formatDistance(spot.distanceMeters ?? 0)} away).';
    }

    if (lowerMessage.contains('library')) {
      final spot = _bestMatchingLocation(
        sourceLocations,
        lat: referenceLat,
        lng: referenceLng,
        predicate: (location) =>
            location.name.toLowerCase().contains('library') ||
            location.aliases.any(
              (alias) => alias.toLowerCase().contains('library'),
            ),
      );
      return spot == null
          ? 'I could not find a campus library right now.'
          : 'Closest library option is ${spot.name} (${_formatDistance(spot.distanceMeters ?? 0)} away).';
    }

    if (lowerMessage.contains('hostel')) {
      final spot = _bestMatchingLocation(
        sourceLocations,
        lat: referenceLat,
        lng: referenceLng,
        predicate: (location) => location.type == 'residential',
      );
      return spot == null
          ? 'I could not find a hostel block right now.'
          : 'Nearest residential block is ${spot.name} (${_formatDistance(spot.distanceMeters ?? 0)} away).';
    }

    if (lowerMessage.contains('help') ||
        lowerMessage.contains('route') ||
        lowerMessage.contains('what can you do')) {
      return 'I can help you find nearby buildings, identify your campus area, suggest food or library spots, and route you between mapped Parul University locations.';
    }

    return 'Try asking for nearby places, your current campus area, the nearest food court, hostel, or a building name like A24, Central Library, or G7.';
  }

  static CampusLocation? _bestMatchingLocation(
    List<CampusLocation> locations, {
    required double lat,
    required double lng,
    required bool Function(CampusLocation location) predicate,
  }) {
    final matches = findNearbyLocations(
      locations,
      lat: lat,
      lng: lng,
      radiusMeters: 2500,
      limit: locations.length,
      predicate: predicate,
    );
    return matches.isEmpty ? null : matches.first;
  }

  static CampusLocation? _findMentionedLocation(
    List<CampusLocation> locations,
    String lowerMessage,
  ) {
    for (final location in locations) {
      if (lowerMessage.contains(location.name.toLowerCase()) ||
          lowerMessage.contains(location.id) ||
          location.aliases.any(
            (alias) => lowerMessage.contains(alias.toLowerCase()),
          )) {
        return location;
      }
    }
    return null;
  }

  static String _formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.round()} m';
  }

  static int _estimateWalkMinutes(double distanceMeters) {
    final minutes = distanceMeters / (1.4 * 60);
    return minutes.round().clamp(1, 180);
  }

  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        _sinSquared(dLat / 2) +
        (_toRadians(lat1).cos() *
            _toRadians(lat2).cos() *
            _sinSquared(dLng / 2));
    final c = 2 * a.sqrt().atan2((1 - a).sqrt());
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double value) => value * (3.141592653589793 / 180);

  static double _sinSquared(double value) {
    final sine = value.sin();
    return sine * sine;
  }

  static Map<String, List<_Neighbor>> _buildGraph(
    List<CampusLocation> locations,
  ) {
    final locationById = {
      for (final location in locations) location.id: location,
    };
    final graph = {
      for (final location in locations) location.id: <_Neighbor>[],
    };

    void addEdge(String fromId, String toId) {
      final from = locationById[fromId];
      final to = locationById[toId];
      if (from == null || to == null) {
        return;
      }

      final neighbors = graph[fromId]!;
      if (neighbors.any((neighbor) => neighbor.targetId == toId)) {
        return;
      }

      neighbors.add(
        _Neighbor(
          targetId: toId,
          distanceMeters: distanceMeters(from.lat, from.lng, to.lat, to.lng),
        ),
      );
    }

    for (final location in locations) {
      for (final targetId in location.connections) {
        addEdge(location.id, targetId);
        addEdge(targetId, location.id);
      }
    }

    return graph;
  }

  static _RouteComputation? _runDijkstra(
    Map<String, List<_Neighbor>> graph,
    String sourceId,
    String destinationId,
  ) {
    if (!graph.containsKey(sourceId) || !graph.containsKey(destinationId)) {
      return null;
    }

    final distances = <String, double>{
      for (final nodeId in graph.keys) nodeId: double.infinity,
    };
    final previous = <String, String?>{
      for (final nodeId in graph.keys) nodeId: null,
    };
    final unvisited = graph.keys.toSet();
    distances[sourceId] = 0;

    while (unvisited.isNotEmpty) {
      String? currentNode;
      var currentDistance = double.infinity;

      for (final nodeId in unvisited) {
        final candidate = distances[nodeId]!;
        if (candidate < currentDistance) {
          currentNode = nodeId;
          currentDistance = candidate;
        }
      }

      if (currentNode == null || currentDistance == double.infinity) {
        break;
      }

      if (currentNode == destinationId) {
        break;
      }

      unvisited.remove(currentNode);

      for (final neighbor in graph[currentNode]!) {
        if (!unvisited.contains(neighbor.targetId)) {
          continue;
        }

        final candidateDistance = currentDistance + neighbor.distanceMeters;
        if (candidateDistance < distances[neighbor.targetId]!) {
          distances[neighbor.targetId] = candidateDistance;
          previous[neighbor.targetId] = currentNode;
        }
      }
    }

    final destinationDistance = distances[destinationId]!;
    if (destinationDistance == double.infinity) {
      return null;
    }

    final pathIds = <String>[];
    String? cursor = destinationId;
    while (cursor != null) {
      pathIds.insert(0, cursor);
      cursor = previous[cursor];
    }

    if (pathIds.isEmpty || pathIds.first != sourceId) {
      return null;
    }

    return _RouteComputation(
      pathIds: pathIds,
      totalDistanceMeters: destinationDistance,
    );
  }
}

class _Neighbor {
  const _Neighbor({required this.targetId, required this.distanceMeters});

  final String targetId;
  final double distanceMeters;
}

class _RouteComputation {
  const _RouteComputation({
    required this.pathIds,
    required this.totalDistanceMeters,
  });

  final List<String> pathIds;
  final double totalDistanceMeters;
}

extension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double atan2(double other) => math.atan2(this, other);
}
