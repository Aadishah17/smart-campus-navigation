import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/assistant_message.dart';
import '../models/campus_location.dart';
import '../models/route_result.dart';
import '../services/api_client.dart';
import '../services/campus_navigation_engine.dart';
import '../widgets/campus_image_map.dart';
import '../widgets/message_bubble.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _apiBaseUrl = defaultApiBaseUrl;
  bool _backendOnline = false;
  bool _dbConnected = false;
  bool _mongoConfigured = false;
  String _dbMode = 'unknown';
  String? _dbError;
  bool _loadingLocations = true;
  bool _loadingRoute = false;
  String _errorText = '';
  bool _usingBundledCampusData = false;
  List<CampusLocation> _locations = const [];
  List<CampusLocation> _nearby = const [];
  RouteResult? _route;
  CampusLocation? _selected;
  String? _sourceId;
  String? _destinationId;
  Set<String> _favoriteIds = <String>{};
  List<String> _recentDestinationIds = <String>[];
  String _typeFilter = 'all';
  double _paceMultiplier = 1.0;
  bool _useGpsSource = true;
  Position? _position;
  bool _gpsOnCampus = false;
  String _gpsStatus = 'Checking GPS...';
  StreamSubscription<Position>? _gpsSub;
  DateTime _lastNearby = DateTime.fromMillisecondsSinceEpoch(0);
  final _searchCtrl = TextEditingController();
  final _assistantCtrl = TextEditingController();
  final _assistantScroll = ScrollController();
  bool _assistantLoading = false;
  late List<AssistantMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = const [
      AssistantMessage(
        role: MessageRole.assistant,
        content:
            'Ask about nearby places, your current campus area, route ideas, or any mapped Parul University building.',
      ),
    ];
    _searchCtrl.addListener(() => setState(() {}));
    unawaited(_init());
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _searchCtrl.dispose();
    _assistantCtrl.dispose();
    _assistantScroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(apiBaseUrlPrefKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _apiBaseUrl = _normalizeBaseUrl(saved);
    }

    _favoriteIds = (prefs.getStringList(favoriteLocationIdsPrefKey) ?? const [])
        .map((id) => id.toLowerCase())
        .toSet();
    _recentDestinationIds =
        (prefs.getStringList(recentDestinationIdsPrefKey) ?? const [])
            .map((id) => id.toLowerCase())
            .toList();

    await _checkBackend();
    await _loadLocations();
    await _startGps();
  }

  String _normalizeBaseUrl(String url) {
    var v = url.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  bool get _isAndroidRuntime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  List<String> _candidateApiBaseUrls([String? preferred]) {
    final candidates = <String>[];
    final seen = <String>{};

    void add(String value) {
      final normalized = _normalizeBaseUrl(value);
      if (normalized.isEmpty || !seen.add(normalized)) {
        return;
      }
      candidates.add(normalized);
    }

    if (preferred != null && preferred.trim().isNotEmpty) {
      add(preferred);
    }

    if (_isAndroidRuntime) {
      add(usbDebugApiBaseUrl);
      add(phoneApiBaseUrl);
      add(emulatorApiBaseUrl);
      return candidates;
    }

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      add(desktopWebApiBaseUrl);
      add(phoneApiBaseUrl);
      return candidates;
    }

    add(defaultApiBaseUrl);
    return candidates;
  }

  Future<void> _persistApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiBaseUrlPrefKey, _normalizeBaseUrl(url));
  }

  ApiClient get _api => ApiClient(baseUrl: _apiBaseUrl);

  CampusLocation get _campusAnchor =>
      CampusNavigationEngine.campusAnchor(_locations);

  Position? get _effectiveUserPosition => _gpsOnCampus ? _position : null;

  String get _dataSourceLabel => _usingBundledCampusData
      ? 'Bundled Parul campus data'
      : 'Live backend sync';

  String get _focusModeLabel => _gpsOnCampus
      ? 'Following your live campus position'
      : 'Pinned to Parul University campus';

  String get _statusBannerText {
    if (_position != null && !_gpsOnCampus) {
      return 'Your GPS appears outside the mapped Parul University campus, so the app is keeping navigation pinned to campus and using Entry Gate as the starting area.';
    }
    if (_usingBundledCampusData) {
      return 'Live backend is unavailable. The app has switched to bundled Parul University data for browsing, nearby suggestions, local routing, and assistant replies.';
    }
    return '';
  }

  Future<void> _checkBackend() async {
    final currentBaseUrl = _apiBaseUrl;

    for (final candidate in _candidateApiBaseUrls(_apiBaseUrl)) {
      try {
        final info = await ApiClient(baseUrl: candidate).fetchHealthInfo();
        if (!mounted) {
          return;
        }
        setState(() {
          _apiBaseUrl = candidate;
          _backendOnline = info.backendOnline;
          _dbConnected = info.databaseConnected;
          _dbMode = info.databaseMode;
          _mongoConfigured = info.mongoConfigured;
          _dbError = info.databaseError;
        });
        if (candidate != currentBaseUrl) {
          await _persistApiBaseUrl(candidate);
        }
        return;
      } catch (_) {
        continue;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _backendOnline = false;
      _dbConnected = false;
      _dbMode = 'unknown';
      _mongoConfigured = false;
      _dbError = null;
    });
  }

  Future<void> _loadLocations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loadingLocations = true;
        _errorText = '';
      });
    }
    try {
      final locations = await _api.fetchLocations();
      if (!mounted) {
        return;
      }
      final validIds = locations.map((location) => location.id).toSet();
      final cleanedFavorites = _favoriteIds
          .where((id) => validIds.contains(id))
          .toSet();
      final cleanedRecent = _recentDestinationIds
          .where((id) => validIds.contains(id))
          .toList();
      setState(() {
        _locations = locations;
        _favoriteIds = cleanedFavorites;
        _recentDestinationIds = cleanedRecent;
        _loadingLocations = false;
        _backendOnline = true;
        _usingBundledCampusData = false;
        if (_locations.isNotEmpty) {
          _sourceId = _contains(_sourceId) ? _sourceId : _locations.first.id;
          _destinationId = _contains(_destinationId)
              ? _destinationId
              : _locations.first.id;
          _selected = _contains(_selected?.id)
              ? _find(_selected!.id)
              : _locations.first;
        }
      });
      unawaited(_saveFavorites());
      unawaited(_saveRecentDestinations());
      await _refreshNearby(force: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final fallbackLocations = CampusNavigationEngine.bundledLocations;
      final validIds = fallbackLocations.map((location) => location.id).toSet();
      setState(() {
        _locations = fallbackLocations;
        _favoriteIds = _favoriteIds
            .where((id) => validIds.contains(id))
            .toSet();
        _recentDestinationIds = _recentDestinationIds
            .where((id) => validIds.contains(id))
            .toList();
        _loadingLocations = false;
        _backendOnline = false;
        _usingBundledCampusData = true;
        if (_locations.isNotEmpty) {
          _sourceId = _contains(_sourceId) ? _sourceId : _campusAnchor.id;
          _destinationId = _contains(_destinationId)
              ? _destinationId
              : _locations.first.id;
          _selected = _contains(_selected?.id)
              ? _find(_selected!.id)
              : _campusAnchor;
        }
        _errorText = '';
      });
      unawaited(_saveFavorites());
      unawaited(_saveRecentDestinations());
      await _refreshNearby(force: true);
    }
  }

  bool _contains(String? id) =>
      id != null && _locations.any((location) => location.id == id);

  CampusLocation _find(String id) =>
      _locations.firstWhere((location) => location.id == id);

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      favoriteLocationIdsPrefKey,
      _favoriteIds.toList()..sort(),
    );
  }

  Future<void> _saveRecentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      recentDestinationIdsPrefKey,
      _recentDestinationIds,
    );
  }

  bool _isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> _toggleFavorite(String id) async {
    final normalized = id.toLowerCase();
    setState(() {
      if (_favoriteIds.contains(normalized)) {
        _favoriteIds.remove(normalized);
      } else {
        _favoriteIds.add(normalized);
      }
    });
    await _saveFavorites();
  }

  Future<void> _pushRecentDestination(String id) async {
    final normalized = id.toLowerCase();
    setState(() {
      _recentDestinationIds = [
        normalized,
        ..._recentDestinationIds.where((item) => item != normalized),
      ].take(6).toList();
    });
    await _saveRecentDestinations();
  }

  List<CampusLocation> _locationsFromIds(List<String> ids) {
    final map = {for (final location in _locations) location.id: location};
    return ids.map((id) => map[id]).whereType<CampusLocation>().toList();
  }

  void _selectLocation(CampusLocation location) {
    setState(() {
      _selected = location;
      _destinationId = location.id;
    });
  }

  CampusLocation? _nearestMatch({
    String? type,
    bool Function(CampusLocation location)? predicate,
  }) {
    if (_locations.isEmpty) {
      return null;
    }

    final referenceLat = _effectiveUserPosition?.latitude ?? _campusAnchor.lat;
    final referenceLng = _effectiveUserPosition?.longitude ?? _campusAnchor.lng;

    final matches = CampusNavigationEngine.findNearbyLocations(
      _locations,
      lat: referenceLat,
      lng: referenceLng,
      radiusMeters: 2500,
      limit: _locations.length,
      predicate: (location) {
        final typeMatches = type == null || location.type == type;
        final predicateMatches = predicate == null || predicate(location);
        return typeMatches && predicateMatches;
      },
    );

    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _routeToQuickDestination(CampusLocation? location) async {
    if (location == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching campus destination found.')),
      );
      return;
    }

    _selectLocation(location);
    await _findRoute();
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.round()} m';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'academic':
        return Icons.school_rounded;
      case 'admin':
        return Icons.apartment_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'dining':
        return Icons.restaurant_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'residential':
        return Icons.king_bed_rounded;
      case 'parking':
        return Icons.local_parking_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'entry':
        return Icons.login_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'academic':
        return const Color(0xFF7DE2D1);
      case 'admin':
        return const Color(0xFFFFC857);
      case 'hospital':
        return const Color(0xFF73E17A);
      case 'dining':
        return const Color(0xFFFFA868);
      case 'sports':
        return const Color(0xFF8EA6FF);
      case 'residential':
        return const Color(0xFF8FD3FF);
      case 'parking':
        return const Color(0xFFF3E37C);
      case 'transport':
        return const Color(0xFFD9D9D9);
      case 'bank':
        return const Color(0xFFFF8FD6);
      case 'entry':
        return const Color(0xFFB7A0FF);
      default:
        return const Color(0xFFE6E6E6);
    }
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x22000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x30FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF9FF0E4)),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFD0D7DB), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x30FFFFFF)),
            color: const Color(0x15000000),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF0E1E22),
                ),
                child: Icon(icon, color: const Color(0xFF86E7DB)),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF9EA3A9), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _displayEstimatedMinutes {
    if (_route == null) {
      return 0;
    }
    return (_route!.estimatedWalkMinutes / _paceMultiplier).ceil();
  }

  String get _paceLabel {
    if (_paceMultiplier < 0.95) {
      return 'Relaxed';
    }
    if (_paceMultiplier > 1.05) {
      return 'Fast';
    }
    return 'Normal';
  }

  Widget _paceOption(double value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _paceMultiplier == value,
      onSelected: (_) => setState(() => _paceMultiplier = value),
    );
  }

  Future<void> _startGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) {
          return;
        }
        setState(() => _gpsStatus = 'Enable location service.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() => _gpsStatus = 'Location permission denied.');
        return;
      }
      final current = await Geolocator.getCurrentPosition();
      final onCampus = CampusNavigationEngine.isOnCampus(
        _locations,
        lat: current.latitude,
        lng: current.longitude,
      );
      if (mounted) {
        setState(() {
          _position = current;
          _gpsOnCampus = onCampus;
          _gpsStatus = onCampus
              ? 'On campus (${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)})'
              : 'GPS active but outside campus focus';
        });
      }
      await _refreshNearby(force: true);
      _gpsSub?.cancel();
      _gpsSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 8,
            ),
          ).listen((pos) {
            if (!mounted) {
              return;
            }
            final onCampus = CampusNavigationEngine.isOnCampus(
              _locations,
              lat: pos.latitude,
              lng: pos.longitude,
            );
            setState(() {
              _position = pos;
              _gpsOnCampus = onCampus;
              _gpsStatus = onCampus
                  ? 'On campus (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})'
                  : 'GPS active but outside campus focus';
            });
            unawaited(_refreshNearby());
          });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _gpsStatus = 'GPS error: $e');
    }
  }

  Future<void> _refreshNearby({bool force = false}) async {
    if (_locations.isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastNearby) < const Duration(seconds: 7)) {
      return;
    }
    _lastNearby = now;

    final referenceLat = _effectiveUserPosition?.latitude ?? _campusAnchor.lat;
    final referenceLng = _effectiveUserPosition?.longitude ?? _campusAnchor.lng;

    try {
      final nearby = _backendOnline && !_usingBundledCampusData
          ? await _api.fetchNearby(lat: referenceLat, lng: referenceLng)
          : CampusNavigationEngine.findNearbyLocations(
              _locations,
              lat: referenceLat,
              lng: referenceLng,
            );
      if (!mounted) {
        return;
      }
      setState(() => _nearby = nearby);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nearby = CampusNavigationEngine.findNearbyLocations(
          _locations,
          lat: referenceLat,
          lng: referenceLng,
        );
      });
    }
  }

  Future<void> _findRoute() async {
    if (_destinationId == null) {
      setState(() => _errorText = 'Choose destination.');
      return;
    }
    if (!_useGpsSource && _sourceId == null) {
      setState(() => _errorText = 'Choose source location.');
      return;
    }
    setState(() {
      _loadingRoute = true;
      _errorText = '';
    });
    final fallbackSourceId = _useGpsSource && !_gpsOnCampus
        ? _campusAnchor.id
        : _sourceId;
    final sourcePosition = _useGpsSource && _gpsOnCampus ? _position : null;

    try {
      RouteResult? route;
      if (_backendOnline && !_usingBundledCampusData) {
        route = await _api.fetchRoute(
          sourceId: _useGpsSource ? fallbackSourceId : _sourceId,
          destinationId: _destinationId!,
          sourcePosition: sourcePosition,
        );
      }

      route ??= CampusNavigationEngine.calculateRoute(
        locations: _locations,
        sourceId: _useGpsSource ? fallbackSourceId : _sourceId,
        destinationId: _destinationId!,
        sourceLat: sourcePosition?.latitude,
        sourceLng: sourcePosition?.longitude,
      );

      if (!mounted) {
        return;
      }

      if (route == null) {
        setState(() {
          _route = null;
          _errorText = 'No campus route was found between those locations.';
        });
        return;
      }

      final resolvedRoute = route;

      setState(() {
        _route = resolvedRoute;
        _selected = resolvedRoute.destination;
        _errorText = '';
      });
      await _pushRecentDestination(resolvedRoute.destination.id);
    } catch (e) {
      final fallbackRoute = CampusNavigationEngine.calculateRoute(
        locations: _locations,
        sourceId: _useGpsSource ? fallbackSourceId : _sourceId,
        destinationId: _destinationId!,
        sourceLat: sourcePosition?.latitude,
        sourceLng: sourcePosition?.longitude,
      );

      if (!mounted) {
        return;
      }

      if (fallbackRoute != null) {
        setState(() {
          _route = fallbackRoute;
          _selected = fallbackRoute.destination;
          _errorText = '';
        });
        await _pushRecentDestination(fallbackRoute.destination.id);
      } else {
        setState(() {
          _route = null;
          _errorText = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRoute = false);
      }
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final msg = (preset ?? _assistantCtrl.text).trim();
    if (msg.isEmpty || _assistantLoading) {
      return;
    }
    setState(() {
      _messages = [
        ..._messages,
        AssistantMessage(role: MessageRole.user, content: msg),
      ];
      _assistantLoading = true;
      if (preset == null) {
        _assistantCtrl.clear();
      }
    });
    _scrollAssistant();
    try {
      final reply = _backendOnline && !_usingBundledCampusData
          ? await _api.askAssistant(
              message: msg,
              position: _effectiveUserPosition,
            )
          : CampusNavigationEngine.assistantReply(
              locations: _locations,
              message: msg,
              userLat: _effectiveUserPosition?.latitude ?? _campusAnchor.lat,
              userLng: _effectiveUserPosition?.longitude ?? _campusAnchor.lng,
              userOnCampus: _gpsOnCampus,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          AssistantMessage(role: MessageRole.assistant, content: reply),
        ];
        _assistantLoading = false;
      });
    } catch (e) {
      final fallbackReply = CampusNavigationEngine.assistantReply(
        locations: _locations,
        message: msg,
        userLat: _effectiveUserPosition?.latitude ?? _campusAnchor.lat,
        userLng: _effectiveUserPosition?.longitude ?? _campusAnchor.lng,
        userOnCampus: _gpsOnCampus,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          AssistantMessage(role: MessageRole.assistant, content: fallbackReply),
        ];
        _assistantLoading = false;
      });
    }
    _scrollAssistant();
  }

  void _scrollAssistant() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_assistantScroll.hasClients) {
        return;
      }
      _assistantScroll.animateTo(
        _assistantScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _copyRouteSummary() async {
    if (_route == null) {
      return;
    }

    final summary = StringBuffer()
      ..writeln('Route: ${_route!.source.name} -> ${_route!.destination.name}')
      ..writeln('Distance: ${_route!.totalDistanceKm.toStringAsFixed(2)} km')
      ..writeln(
        'Estimated walk (${_paceLabel.toLowerCase()}): $_displayEstimatedMinutes min',
      )
      ..writeln(
        'Path: ${_route!.path.map((location) => location.name).join(" -> ")}',
      );

    await Clipboard.setData(ClipboardData(text: summary.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Route summary copied to clipboard.')),
    );
  }

  Future<void> _openSettings() async {
    final ctrl = TextEditingController(text: _apiBaseUrl);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Base URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(hintText: phoneApiBaseUrl),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => ctrl.text = usbDebugApiBaseUrl,
                  child: const Text('Use USB URL'),
                ),
                OutlinedButton(
                  onPressed: () => ctrl.text = phoneApiBaseUrl,
                  child: const Text('Use Phone URL'),
                ),
                OutlinedButton(
                  onPressed: () => ctrl.text = emulatorApiBaseUrl,
                  child: const Text('Use Emulator URL'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.text = defaultApiBaseUrl;
            },
            child: const Text('Default'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeBaseUrl(value);
    await prefs.setString(apiBaseUrlPrefKey, normalized);
    if (!mounted) {
      return;
    }
    setState(() => _apiBaseUrl = normalized);
    await _checkBackend();
    await _loadLocations();
  }

  Future<void> _refreshAll() async {
    await _checkBackend();
    await _loadLocations(showLoader: false);
    await _refreshNearby(force: true);
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0x2218B5A7),
            border: Border.all(color: const Color(0x445FD1C5)),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF8DE9DE)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9EA3A9),
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTypes =
        _locations.map((location) => location.type).toSet().toList()..sort();
    final query = _searchCtrl.text.toLowerCase().trim();
    final filtered = _locations.where((location) {
      final typeMatches = _typeFilter == 'all' || location.type == _typeFilter;
      final queryMatches =
          query.isEmpty ||
          location.id.toLowerCase().contains(query) ||
          location.name.toLowerCase().contains(query) ||
          location.type.toLowerCase().contains(query) ||
          location.aliases.any((alias) => alias.toLowerCase().contains(query));
      return typeMatches && queryMatches;
    }).toList();
    filtered.sort((a, b) {
      final aFav = _isFavorite(a.id);
      final bFav = _isFavorite(b.id);
      if (aFav != bFav) {
        return aFav ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    final favoriteLocations = _locationsFromIds(_favoriteIds.toList()..sort());
    final recentDestinations = _locationsFromIds(_recentDestinationIds);
    final routeLegs = _route == null
        ? const <CampusRouteLeg>[]
        : CampusNavigationEngine.buildRouteLegs(_route!.path);
    final routeSourceLabel = _route == null
        ? (_useGpsSource
              ? (_gpsOnCampus ? 'Live campus GPS' : _campusAnchor.name)
              : (_sourceId == null ? 'Manual source' : _find(_sourceId!).name))
        : _route!.source.name;
    final activeDestination = _selected ?? _campusAnchor;
    final activeColor = _colorForType(activeDestination.type);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Parul University Navigator'),
          titleSpacing: 16,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xCC102028),
                  Color(0x7706080A),
                  Color(0xFF020508),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: _refreshAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.map_outlined), text: 'Navigate'),
              Tab(icon: Icon(Icons.chat_outlined), text: 'Assistant'),
              Tab(icon: Icon(Icons.info_outline), text: 'About'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeColor.withValues(alpha: 0.26),
                            const Color(0xAA081014),
                            const Color(0xFF05080B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: const Color(0x22000000),
                                    border: Border.all(
                                      color: const Color(0x35FFFFFF),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.explore_rounded,
                                    color: Color(0xFF9EF0E4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Parul University Wayfinding',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Smooth in-campus navigation for admissions, classrooms, hostels, dining, and hospital blocks.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.78,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: Icon(
                                    _backendOnline
                                        ? Icons.cloud_done_rounded
                                        : Icons.cloud_off_rounded,
                                    size: 16,
                                  ),
                                  label: Text(_dataSourceLabel),
                                ),
                                Chip(
                                  avatar: Icon(
                                    _gpsOnCampus
                                        ? Icons.gps_fixed_rounded
                                        : Icons.map_rounded,
                                    size: 16,
                                  ),
                                  label: Text(_focusModeLabel),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.flag_rounded,
                                    size: 16,
                                  ),
                                  label: Text(activeDestination.name),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _metricTile(
                                  icon: Icons.place_rounded,
                                  label: 'Mapped places',
                                  value: '${_locations.length}',
                                ),
                                const SizedBox(width: 10),
                                _metricTile(
                                  icon: Icons.near_me_rounded,
                                  label: 'Nearby now',
                                  value: '${_nearby.length}',
                                ),
                                const SizedBox(width: 10),
                                _metricTile(
                                  icon: Icons.route_rounded,
                                  label: 'Route ETA',
                                  value: _route == null
                                      ? '--'
                                      : '$_displayEstimatedMinutes min',
                                ),
                              ],
                            ),
                            if (recentDestinations.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Text(
                                'Recent destinations',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: recentDestinations
                                    .take(4)
                                    .map(
                                      (location) => ActionChip(
                                        avatar: const Icon(
                                          Icons.history_rounded,
                                          size: 16,
                                        ),
                                        label: Text(location.name),
                                        onPressed: () =>
                                            _selectLocation(location),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_statusBannerText.isNotEmpty)
                    Card(
                      color: const Color(0x1D5FD1C5),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF9EF0E4),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_statusBannerText)),
                          ],
                        ),
                      ),
                    ),
                  if (_statusBannerText.isNotEmpty) const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.flash_on_rounded,
                            title: 'Quick Campus Actions',
                            subtitle:
                                'One tap to plan routes to the most common campus needs',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _quickAction(
                                icon: Icons.meeting_room_rounded,
                                title: 'Admissions',
                                subtitle: 'Jump to C2 Admission Cell',
                                onTap: () => _routeToQuickDestination(
                                  CampusNavigationEngine.findById(
                                    _locations,
                                    'c2-admission-cell',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _quickAction(
                                icon: Icons.local_library_rounded,
                                title: 'Nearest Library',
                                subtitle: 'Pick the closest study block',
                                onTap: () => _routeToQuickDestination(
                                  _nearestMatch(
                                    predicate: (location) =>
                                        location.name.toLowerCase().contains(
                                          'library',
                                        ) ||
                                        location.aliases.any(
                                          (alias) => alias
                                              .toLowerCase()
                                              .contains('library'),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _quickAction(
                                icon: Icons.restaurant_rounded,
                                title: 'Nearest Food',
                                subtitle: 'Route to the closest food court',
                                onTap: () => _routeToQuickDestination(
                                  _nearestMatch(type: 'dining'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _quickAction(
                                icon: Icons.local_hospital_rounded,
                                title: 'Medical Help',
                                subtitle: 'Navigate to hospital support',
                                onTap: () => _routeToQuickDestination(
                                  _nearestMatch(
                                    predicate: (location) =>
                                        location.type == 'hospital' ||
                                        location.name.toLowerCase().contains(
                                          'medical',
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.podcasts_rounded,
                            title: 'System Status',
                            subtitle:
                                'Backend, database, GPS, and campus focus state',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  _backendOnline
                                      ? 'Backend Online'
                                      : 'Backend Offline',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  'DB: ${_dbMode.toUpperCase()}${_dbConnected ? " Connected" : ""}',
                                ),
                              ),
                              Chip(label: Text('GPS: $_gpsStatus')),
                              Chip(label: Text('Source: $routeSourceLabel')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'API: $_apiBaseUrl',
                            style: const TextStyle(
                              color: Color(0xFFB8B8B8),
                              fontSize: 12,
                            ),
                          ),
                          if (_dbMode == 'seed')
                            Text(
                              _mongoConfigured
                                  ? 'MongoDB is configured but currently unavailable. The backend is serving seed data.'
                                  : 'MongoDB is not configured. The backend is serving seed data.',
                              style: const TextStyle(
                                color: Color(0xFFB8B8B8),
                                fontSize: 12,
                              ),
                            ),
                          if (_dbError != null && _dbError!.trim().isNotEmpty)
                            Text(
                              'DB error: $_dbError',
                              style: const TextStyle(
                                color: Color(0xFFB8B8B8),
                                fontSize: 12,
                              ),
                            ),
                          if (!_backendOnline &&
                              _apiBaseUrl.contains('10.0.2.2'))
                            Text(
                              'Tip: 10.0.2.2 works only on the Android emulator. For a real phone, update the API URL to your PC LAN address in settings.',
                              style: const TextStyle(
                                color: Color(0xFFB8B8B8),
                                fontSize: 12,
                              ),
                            ),
                          if (!_backendOnline &&
                              _apiBaseUrl.contains('127.0.0.1'))
                            Text(
                              'Tip: 127.0.0.1 on Android needs USB port reverse. If USB is disconnected, switch to the phone LAN URL in settings.',
                              style: const TextStyle(
                                color: Color(0xFFB8B8B8),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.route_rounded,
                            title: 'Route Planner',
                            subtitle:
                                'Shortest path with campus-safe source fallback and live map overlays',
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Use GPS as Source'),
                            value: _useGpsSource,
                            onChanged: (v) => setState(() => _useGpsSource = v),
                          ),
                          if (_useGpsSource && !_gpsOnCampus)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0x14000000),
                                border: Border.all(
                                  color: const Color(0x25FFFFFF),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.my_location_rounded,
                                    color: Color(0xFF9EF0E4),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'GPS is currently outside campus focus. Route planning will start from ${_campusAnchor.name}.',
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!_useGpsSource)
                            DropdownButtonFormField<String>(
                              initialValue: _contains(_sourceId)
                                  ? _sourceId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Source',
                              ),
                              items: _locations
                                  .map(
                                    (loc) => DropdownMenuItem(
                                      value: loc.id,
                                      child: Text(loc.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _sourceId = v),
                            ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _contains(_destinationId)
                                ? _destinationId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Destination',
                            ),
                            items: _locations
                                .map(
                                  (loc) => DropdownMenuItem(
                                    value: loc.id,
                                    child: Text(loc.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) {
                                return;
                              }
                              _selectLocation(_find(v));
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0x12000000),
                              border: Border.all(
                                color: const Color(0x25FFFFFF),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: activeColor.withValues(alpha: 0.18),
                                  ),
                                  child: Icon(
                                    _iconForType(activeDestination.type),
                                    color: activeColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected destination',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.68,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        activeDestination.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: (_loadingRoute || _loadingLocations)
                                  ? null
                                  : _findRoute,
                              icon: Icon(
                                _loadingRoute
                                    ? Icons.hourglass_top
                                    : Icons.route,
                              ),
                              label: Text(
                                _loadingRoute
                                    ? 'Calculating...'
                                    : 'Find Shortest Path',
                              ),
                            ),
                          ),
                          if (favoriteLocations.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Quick Favorites',
                              style: TextStyle(
                                color: Color(0xFF9EA3A9),
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: favoriteLocations
                                  .take(6)
                                  .map(
                                    (location) => ActionChip(
                                      avatar: const Icon(
                                        Icons.favorite_rounded,
                                        size: 15,
                                      ),
                                      label: Text(location.name),
                                      onPressed: () =>
                                          _selectLocation(location),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _errorText.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Card(
                              color: const Color(0x331F1010),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFFFB4B4),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_errorText)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.public_rounded,
                            title: 'Live Integrated Map',
                            subtitle:
                                'Campus guide map with live navigation, route focus, and GPS tracking',
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 520,
                            child: _loadingLocations
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : CampusImageMap(
                                    locations: _locations,
                                    routePath: _route?.path ?? const [],
                                    selectedLocationId: _selected?.id,
                                    userPosition: _effectiveUserPosition,
                                    focusLabel: _focusModeLabel,
                                    highlightLabel: activeDestination.name,
                                    onSelectLocation: (id) =>
                                        _selectLocation(_find(id)),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_route != null) ...[
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                              icon: Icons.timeline_rounded,
                              title: 'Route Summary',
                              subtitle:
                                  'Customize pace, inspect legs, and copy directions',
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0x12000000),
                                border: Border.all(
                                  color: const Color(0x25FFFFFF),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'From: ${_route!.source.name}\nTo: ${_route!.destination.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: const Color(0xFF0E1E22),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_route!.totalDistanceKm.toStringAsFixed(2)} km',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '$_displayEstimatedMinutes min',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _paceOption(0.8, 'Relaxed'),
                                _paceOption(1.0, 'Normal'),
                                _paceOption(1.2, 'Fast'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _route!.path
                                  .map((loc) => Chip(label: Text(loc.name)))
                                  .toList(),
                            ),
                            if (routeLegs.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Route legs',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              ...routeLegs.asMap().entries.map(
                                (entry) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0x22000000),
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  title: Text(entry.value.to.name),
                                  subtitle: Text(entry.value.from.name),
                                  trailing: Text(
                                    _formatDistance(entry.value.distanceMeters),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _copyRouteSummary,
                              icon: const Icon(Icons.copy_all_rounded),
                              label: const Text('Copy Route Summary'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_selected != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _colorForType(
                                      _selected!.type,
                                    ).withValues(alpha: 0.18),
                                  ),
                                  child: Icon(
                                    _iconForType(_selected!.type),
                                    color: _colorForType(_selected!.type),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selected!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selected!.id.toUpperCase()} • ${_selected!.type}',
                                        style: const TextStyle(
                                          color: Color(0xFF9EA3A9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _routeToQuickDestination(_selected),
                                  icon: const Icon(Icons.navigation_rounded),
                                  label: const Text('Route'),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: _isFavorite(_selected!.id)
                                      ? 'Remove favorite'
                                      : 'Add favorite',
                                  onPressed: () =>
                                      _toggleFavorite(_selected!.id),
                                  icon: Icon(
                                    _isFavorite(_selected!.id)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: _isFavorite(_selected!.id)
                                        ? const Color(0xFF77E0D5)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(_selected!.description),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.place_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '${_selected!.lat.toStringAsFixed(5)}, ${_selected!.lng.toStringAsFixed(5)}',
                                  ),
                                ),
                                if (_selected!.distanceMeters != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.near_me_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _formatDistance(
                                        _selected!.distanceMeters!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_selected!.facilities.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _selected!.facilities
                                    .map(
                                      (facility) => Chip(
                                        avatar: const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 15,
                                        ),
                                        label: Text(facility),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.near_me_rounded,
                            title: 'Nearby Places',
                            subtitle: _gpsOnCampus
                                ? 'Auto-updates from your live campus position'
                                : 'Showing places nearest to the Parul campus focus point',
                          ),
                          const SizedBox(height: 8),
                          if (_nearby.isEmpty)
                            const Text(
                              'No nearby places yet.',
                              style: TextStyle(color: Color(0xFFB8B8B8)),
                            )
                          else
                            ..._nearby.map(
                              (loc) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _colorForType(
                                    loc.type,
                                  ).withValues(alpha: 0.18),
                                  child: Icon(
                                    _iconForType(loc.type),
                                    size: 18,
                                    color: _colorForType(loc.type),
                                  ),
                                ),
                                title: Text(loc.name),
                                subtitle: Text(loc.type),
                                trailing: Text(
                                  loc.distanceMeters == null
                                      ? '-'
                                      : '${loc.distanceMeters!.round()} m',
                                ),
                                onTap: () => _selectLocation(_find(loc.id)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.travel_explore_rounded,
                            title: 'Search & Explore',
                            subtitle:
                                'Filter by location type and bookmark favorites',
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Search id/name/type',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('All'),
                                  selected: _typeFilter == 'all',
                                  onSelected: (_) =>
                                      setState(() => _typeFilter = 'all'),
                                ),
                                const SizedBox(width: 6),
                                ...allTypes.map(
                                  (type) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(type),
                                      selected: _typeFilter == type,
                                      onSelected: (_) =>
                                          setState(() => _typeFilter = type),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (filtered.isEmpty)
                            const Text(
                              'No locations match your current search/filter.',
                              style: TextStyle(color: Color(0xFF9EA3A9)),
                            )
                          else
                            ...filtered
                                .take(8)
                                .map(
                                  (loc) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: _colorForType(
                                        loc.type,
                                      ).withValues(alpha: 0.18),
                                      child: Icon(
                                        _iconForType(loc.type),
                                        size: 18,
                                        color: _colorForType(loc.type),
                                      ),
                                    ),
                                    title: Text(loc.name),
                                    subtitle: Text(
                                      '${loc.id.toUpperCase()} • ${loc.type}',
                                    ),
                                    trailing: IconButton(
                                      tooltip: _isFavorite(loc.id)
                                          ? 'Remove favorite'
                                          : 'Add favorite',
                                      onPressed: () => _toggleFavorite(loc.id),
                                      icon: Icon(
                                        _isFavorite(loc.id)
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 20,
                                        color: _isFavorite(loc.id)
                                            ? const Color(0xFF77E0D5)
                                            : null,
                                      ),
                                    ),
                                    onTap: () => _selectLocation(loc),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                          ),
                          label: const Text('Where am I?'),
                          onPressed: () => _sendMessage('Where am I?'),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.restaurant_rounded,
                            size: 16,
                          ),
                          label: const Text('Nearest Food'),
                          onPressed: () =>
                              _sendMessage('Show nearby food courts'),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.local_library_rounded,
                            size: 16,
                          ),
                          label: const Text('Library details'),
                          onPressed: () =>
                              _sendMessage('Tell me about library'),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.meeting_room_rounded,
                            size: 16,
                          ),
                          label: const Text('Admissions'),
                          onPressed: () =>
                              _sendMessage('Tell me about admission cell'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: ListView.builder(
                        controller: _assistantScroll,
                        padding: const EdgeInsets.all(12),
                        itemCount:
                            _messages.length + (_assistantLoading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (_assistantLoading && i == _messages.length) {
                            return const MessageBubble(
                              text: 'Thinking...',
                              role: MessageRole.assistant,
                            );
                          }
                          final msg = _messages[i];
                          return MessageBubble(
                            text: msg.content,
                            role: msg.role,
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _assistantCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Ask anything about campus...',
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _assistantLoading ? null : _sendMessage,
                          child: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
              children: const [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'This Flutter app is tuned specifically for Parul University campus navigation. '
                      'It supports campus-focused GPS behavior, quick destination shortcuts, favorites, recent destinations, route leg breakdowns, and assistant guidance.',
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'When the backend is offline, the app now falls back to bundled Parul University map data for browsing, nearby suggestions, local routing, and assistant replies.\n\n'
                      'Backend for emulator: $emulatorApiBaseUrl\n'
                      'Backend for USB debugging with adb reverse: $usbDebugApiBaseUrl\n'
                      'Backend for real Android phone or wireless debugging: replace with your PC LAN IP in settings.',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
