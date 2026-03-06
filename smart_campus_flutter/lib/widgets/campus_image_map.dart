import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/guide_map_projection.dart';
import '../models/campus_location.dart';

class CampusImageMap extends StatefulWidget {
  const CampusImageMap({
    required this.locations,
    required this.routePath,
    required this.selectedLocationId,
    required this.userPosition,
    required this.onSelectLocation,
    super.key,
  });

  final List<CampusLocation> locations;
  final List<CampusLocation> routePath;
  final String? selectedLocationId;
  final Position? userPosition;
  final ValueChanged<String> onSelectLocation;

  @override
  State<CampusImageMap> createState() => _CampusImageMapState();
}

class _CampusImageMapState extends State<CampusImageMap> {
  final MapController _mapController = MapController();

  bool _showNetwork = true;
  bool _showLabels = false;
  bool _followUser = false;
  double _liveZoom = -1.6;

  @override
  void didUpdateWidget(covariant CampusImageMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldSignature = _routeSignature(oldWidget.routePath);
    final newSignature = _routeSignature(widget.routePath);
    if (oldSignature == newSignature) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final projection = GuideMapProjection(widget.locations);
      final userPoint = _userMapPoint(projection);

      if (widget.routePath.length > 1) {
        _fitToRoute(projection, userPoint);
        return;
      }

      if (oldWidget.routePath.isNotEmpty) {
        _fitToCampus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final projection = GuideMapProjection(widget.locations);
    final routePoints = projection.routeMapPoints(widget.routePath);
    final networkSegments = projection.buildNetworkPolylines();
    final userPoint = _userMapPoint(projection);
    final routeStartId = widget.routePath.isEmpty
        ? null
        : widget.routePath.first.id;
    final routeEndId = widget.routePath.isEmpty
        ? null
        : widget.routePath.last.id;

    _followUserIfEnabled(userPoint);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              crs: const CrsSimple(),
              initialCenter: const LatLng(
                -guideMapCanvasHeight / 2,
                guideMapCanvasWidth / 2,
              ),
              initialZoom: _liveZoom,
              initialCameraFit: CameraFit.bounds(
                bounds: guideMapBounds,
                padding: const EdgeInsets.fromLTRB(28, 76, 28, 40),
              ),
              minZoom: -3.6,
              maxZoom: 1.2,
              backgroundColor: const Color(0xFFE8E3D8),
              cameraConstraint: CameraConstraint.contain(
                bounds: guideMapBounds,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, point) => _selectNearest(projection, point),
              onPositionChanged: (camera, hasGesture) {
                _liveZoom = camera.zoom;
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: guideMapBounds,
                    imageProvider: const AssetImage(
                      'assets/images/parul-campus-map.jpg',
                    ),
                  ),
                ],
              ),
              if (_showNetwork)
                PolylineLayer(polylines: _networkPolylines(networkSegments)),
              if (userPoint != null && widget.routePath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        userPoint,
                        projection.mapPointForLocation(widget.routePath.first),
                      ],
                      strokeWidth: 3,
                      color: const Color(0xB3226CFF),
                    ),
                  ],
                ),
              if (routePoints.length > 1)
                PolylineLayer(polylines: _routePolylines(routePoints)),
              if (widget.locations.isNotEmpty)
                MarkerLayer(
                  markers: _locationMarkers(
                    projection: projection,
                    selectedId: widget.selectedLocationId,
                    routeStartId: routeStartId,
                    routeEndId: routeEndId,
                  ),
                ),
              if (userPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 34,
                      height: 34,
                      point: userPoint,
                      child: const _UserDot(),
                    ),
                  ],
                ),
            ],
          ),
        ),
        _buildTopControls(
          routeActive: widget.routePath.length > 1,
          projection: projection,
          userPoint: userPoint,
        ),
        _buildSideControls(projection, userPoint),
      ],
    );
  }

  Widget _buildTopControls({
    required bool routeActive,
    required GuideMapProjection projection,
    required LatLng? userPoint,
  }) {
    final statusText = routeActive
        ? 'Live route is pinned to the campus guide map'
        : 'Tap any building marker to plan from the route panel';

    return Positioned(
      top: 8,
      left: 8,
      right: 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD80A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Guide Navigation',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFD0D0D0),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chipButton(
                    label: _showNetwork ? 'Graph On' : 'Graph Off',
                    active: _showNetwork,
                    onTap: () => setState(() => _showNetwork = !_showNetwork),
                  ),
                  _chipButton(
                    label: _showLabels ? 'Labels On' : 'Labels Off',
                    active: _showLabels,
                    onTap: () => setState(() => _showLabels = !_showLabels),
                  ),
                  _chipButton(
                    label: routeActive ? 'Focus Route' : 'Full Campus',
                    active: routeActive,
                    onTap: () {
                      if (routeActive) {
                        _fitToRoute(projection, userPoint);
                      } else {
                        _fitToCampus();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? const Color(0xFFFBF7EA) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF121212) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideControls(GuideMapProjection projection, LatLng? userPoint) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD80A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          children: [
            IconButton(
              tooltip: 'Zoom in',
              onPressed: _zoomIn,
              icon: const Icon(Icons.add_rounded),
            ),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: _zoomOut,
              icon: const Icon(Icons.remove_rounded),
            ),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            IconButton(
              tooltip: 'Reset campus view',
              onPressed: _fitToCampus,
              icon: const Icon(Icons.crop_free_rounded),
            ),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            IconButton(
              tooltip: widget.routePath.length > 1
                  ? 'Fit active route'
                  : (userPoint != null
                        ? 'Center on my position'
                        : 'Fit campus'),
              onPressed: () {
                if (widget.routePath.length > 1) {
                  _fitToRoute(projection, userPoint);
                  return;
                }

                if (userPoint != null) {
                  _mapController.move(
                    userPoint,
                    math.max(_mapController.camera.zoom, -0.2),
                  );
                  return;
                }

                _fitToCampus();
              },
              icon: const Icon(Icons.route_rounded),
            ),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            IconButton(
              tooltip: _followUser
                  ? 'Disable follow mode'
                  : 'Follow my position',
              onPressed: userPoint == null
                  ? null
                  : () => setState(() => _followUser = !_followUser),
              icon: Icon(
                _followUser
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Polyline> _routePolylines(List<LatLng> routePoints) {
    return [
      Polyline(
        points: routePoints,
        strokeWidth: 10,
        color: const Color(0x66000000),
      ),
      Polyline(
        points: routePoints,
        strokeWidth: 5,
        color: const Color(0xFFF9FFF0),
      ),
      Polyline(
        points: routePoints,
        strokeWidth: 2.5,
        color: const Color(0xFF2B7FFF),
      ),
    ];
  }

  List<Polyline> _networkPolylines(List<List<LatLng>> segments) {
    return segments
        .map(
          (segment) => Polyline(
            points: segment,
            strokeWidth: 2,
            color: const Color(0x78FFFFFF),
          ),
        )
        .toList();
  }

  List<Marker> _locationMarkers({
    required GuideMapProjection projection,
    required String? selectedId,
    required String? routeStartId,
    required String? routeEndId,
  }) {
    return widget.locations.map((location) {
      final selected = location.id == selectedId;
      final isRouteStart = location.id == routeStartId;
      final isRouteEnd = location.id == routeEndId;
      final showLabel = _showLabels || selected || isRouteStart || isRouteEnd;
      final labelText = isRouteEnd
          ? 'Arrive · ${location.name}'
          : isRouteStart
          ? 'Start · ${location.name}'
          : location.name;

      return Marker(
        width: showLabel ? 190 : 30,
        height: showLabel ? 78 : 30,
        point: projection.mapPointForLocation(location),
        child: GestureDetector(
          onTap: () => widget.onSelectLocation(location.id),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _LabelBubble(text: labelText),
                ),
              _MapMarker(
                type: location.type,
                selected: selected,
                isRouteStart: isRouteStart,
                isRouteEnd: isRouteEnd,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _zoomIn() {
    final zoom = (_mapController.camera.zoom + 0.5).clamp(-3.6, 1.2);
    _mapController.move(_mapController.camera.center, zoom.toDouble());
  }

  void _zoomOut() {
    final zoom = (_mapController.camera.zoom - 0.5).clamp(-3.6, 1.2);
    _mapController.move(_mapController.camera.center, zoom.toDouble());
  }

  void _fitToCampus() {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: guideMapBounds,
        padding: const EdgeInsets.fromLTRB(28, 76, 28, 40),
      ),
    );
  }

  void _fitToRoute(GuideMapProjection projection, LatLng? userPoint) {
    if (widget.routePath.isEmpty) {
      _fitToCampus();
      return;
    }

    final routePoints = projection.routeMapPoints(widget.routePath);
    final extraPoints = userPoint == null
        ? const <LatLng>[]
        : <LatLng>[userPoint];
    final coordinates = <LatLng>[...routePoints, ...extraPoints];

    if (coordinates.length <= 1) {
      _mapController.move(
        coordinates.first,
        math.max(_mapController.camera.zoom, -0.2),
      );
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: coordinates,
        padding: const EdgeInsets.fromLTRB(56, 90, 56, 56),
        minZoom: -3.0,
        maxZoom: 0.55,
      ),
    );
  }

  void _followUserIfEnabled(LatLng? userPoint) {
    if (!_followUser || userPoint == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final center = _mapController.camera.center;
      final deltaX = center.longitude - userPoint.longitude;
      final deltaY = center.latitude - userPoint.latitude;
      final distance = math.sqrt((deltaX * deltaX) + (deltaY * deltaY));
      if (distance < 18) {
        return;
      }

      _mapController.move(
        userPoint,
        math.max(_mapController.camera.zoom, -0.1),
      );
    });
  }

  void _selectNearest(GuideMapProjection projection, LatLng tapPoint) {
    if (widget.locations.isEmpty) {
      return;
    }

    final tapProjected = _mapController.camera.projectAtZoom(
      tapPoint,
      _mapController.camera.zoom,
    );
    CampusLocation? nearest;
    var nearestDistance = double.infinity;

    for (final location in widget.locations) {
      final projected = _mapController.camera.projectAtZoom(
        projection.mapPointForLocation(location),
        _mapController.camera.zoom,
      );
      final deltaX = (projected.dx - tapProjected.dx).toDouble();
      final deltaY = (projected.dy - tapProjected.dy).toDouble();
      final distance = math.sqrt((deltaX * deltaX) + (deltaY * deltaY));

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = location;
      }
    }

    if (nearest != null && nearestDistance <= 34) {
      widget.onSelectLocation(nearest.id);
    }
  }

  LatLng? _userMapPoint(GuideMapProjection projection) {
    final position = widget.userPosition;
    if (position == null) {
      return null;
    }

    return projection.mapPointForPosition(
      position.latitude,
      position.longitude,
    );
  }

  String _routeSignature(List<CampusLocation> path) {
    return path.map((location) => location.id).join('>');
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.type,
    required this.selected,
    required this.isRouteStart,
    required this.isRouteEnd,
  });

  final String type;
  final bool selected;
  final bool isRouteStart;
  final bool isRouteEnd;

  @override
  Widget build(BuildContext context) {
    final (fillColor, strokeColor) = _markerColors();
    final size = selected || isRouteStart || isRouteEnd ? 22.0 : 16.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(
          color: strokeColor,
          width: selected || isRouteStart || isRouteEnd ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }

  (Color, Color) _markerColors() {
    if (isRouteEnd) {
      return (const Color(0xFFFFF3D1), const Color(0xFF7B4B00));
    }
    if (isRouteStart) {
      return (const Color(0xFFDFFBF7), const Color(0xFF00564A));
    }
    if (selected) {
      return (Colors.white, Colors.black);
    }

    switch (type.toLowerCase()) {
      case 'academic':
        return (const Color(0xFFD84040), const Color(0xFF510000));
      case 'admin':
        return (const Color(0xFF5D50CC), const Color(0xFF1E1768));
      case 'hospital':
        return (const Color(0xFF2DAA66), const Color(0xFF0B4B27));
      case 'dining':
        return (const Color(0xFFF2993B), const Color(0xFF7A3D00));
      case 'sports':
        return (const Color(0xFF7B4ACD), const Color(0xFF34156B));
      case 'residential':
        return (const Color(0xFF38A7D8), const Color(0xFF003B59));
      case 'facility':
        return (const Color(0xFFF0C24A), const Color(0xFF6C4C00));
      case 'parking':
        return (const Color(0xFFF1D447), const Color(0xFF766000));
      case 'transport':
        return (const Color(0xFF444444), const Color(0xFF111111));
      case 'bank':
        return (const Color(0xFFE6409C), const Color(0xFF63003D));
      case 'entry':
        return (const Color(0xFF5C48D0), const Color(0xFF20126D));
      default:
        return (const Color(0xFF9E9E9E), Colors.black);
    }
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2E82FF),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xAA0B51B3), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LabelBubble extends StatelessWidget {
  const _LabelBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE9111111),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x44FFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
