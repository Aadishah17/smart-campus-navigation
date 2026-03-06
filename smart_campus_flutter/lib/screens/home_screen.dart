import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/assistant_message.dart';
import '../models/campus_location.dart';
import '../models/route_result.dart';
import '../services/api_client.dart';
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
        content: 'Ask about nearby places, your location, or building info.',
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
      final normalized = _normalizeBaseUrl(saved);
      _apiBaseUrl = normalized == emulatorApiBaseUrl
          ? defaultApiBaseUrl
          : normalized;
      if (_apiBaseUrl != normalized) {
        await prefs.setString(apiBaseUrlPrefKey, _apiBaseUrl);
      }
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

  ApiClient get _api => ApiClient(baseUrl: _apiBaseUrl);

  Future<void> _checkBackend() async {
    try {
      final info = await _api.fetchHealthInfo();
      if (!mounted) {
        return;
      }
      setState(() {
        _backendOnline = info.backendOnline;
        _dbConnected = info.databaseConnected;
        _dbMode = info.databaseMode;
        _mongoConfigured = info.mongoConfigured;
        _dbError = info.databaseError;
      });
    } catch (_) {
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
      setState(() {
        _loadingLocations = false;
        _backendOnline = false;
        _errorText = e.toString();
      });
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
      if (mounted) {
        setState(() {
          _position = current;
          _gpsStatus =
              'GPS active (${current.latitude.toStringAsFixed(5)}, ${current.longitude.toStringAsFixed(5)})';
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
            setState(() {
              _position = pos;
              _gpsStatus =
                  'GPS active (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
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
    if (_position == null) {
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastNearby) < const Duration(seconds: 7)) {
      return;
    }
    _lastNearby = now;
    try {
      final nearby = await _api.fetchNearby(
        lat: _position!.latitude,
        lng: _position!.longitude,
      );
      if (!mounted) {
        return;
      }
      setState(() => _nearby = nearby);
    } catch (_) {}
  }

  Future<void> _findRoute() async {
    if (_destinationId == null) {
      setState(() => _errorText = 'Choose destination.');
      return;
    }
    if (_useGpsSource && _position == null) {
      setState(
        () => _errorText = 'GPS source selected but location unavailable.',
      );
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
    try {
      final route = await _api.fetchRoute(
        sourceId: _useGpsSource ? null : _sourceId,
        destinationId: _destinationId!,
        sourcePosition: _useGpsSource ? _position : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _route = route;
        _selected = route.destination;
      });
      await _pushRecentDestination(route.destination.id);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _route = null;
        _errorText = e.toString();
      });
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
      final reply = await _api.askAssistant(message: msg, position: _position);
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
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          AssistantMessage(
            role: MessageRole.assistant,
            content: 'Assistant error: $e',
          ),
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Smart Campus Navigator'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x770F1B21), Color(0x22050607)],
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
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            icon: Icons.podcasts_rounded,
                            title: 'System Status',
                            subtitle:
                                'Live backend, database, and GPS telemetry',
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
                              Chip(
                                label: Text('Locations: ${_locations.length}'),
                              ),
                              Chip(
                                label: Text(
                                  _useGpsSource
                                      ? 'Source: GPS'
                                      : 'Source: Manual',
                                ),
                              ),
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
                          Text(
                            'GPS: $_gpsStatus',
                            style: const TextStyle(
                              color: Color(0xFFB8B8B8),
                              fontSize: 12,
                            ),
                          ),
                          if (_dbMode == 'seed')
                            Text(
                              _mongoConfigured
                                  ? 'MongoDB unavailable. Using seed fallback data.'
                                  : 'MongoDB not configured. Using seed fallback data.',
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
                              'Tip: 10.0.2.2 works only on the Android emulator. For your phone use $phoneApiBaseUrl.',
                              style: TextStyle(
                                color: Color(0xFFB8B8B8),
                                fontSize: 12,
                              ),
                            ),
                          if (recentDestinations.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Recent Destinations',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: recentDestinations
                                  .map(
                                    (location) => ActionChip(
                                      label: Text(location.name),
                                      onPressed: () => setState(() {
                                        _destinationId = location.id;
                                        _selected = location;
                                      }),
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
                            icon: Icons.route_rounded,
                            title: 'Route Planner',
                            subtitle: 'Shortest path with live map overlays',
                          ),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Use GPS as Source'),
                            value: _useGpsSource,
                            onChanged: (v) => setState(() => _useGpsSource = v),
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
                            onChanged: (v) =>
                                setState(() => _destinationId = v),
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
                                      onPressed: () => setState(() {
                                        _destinationId = location.id;
                                        _selected = location;
                                      }),
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
                                    userPosition: _position,
                                    onSelectLocation: (id) => setState(() {
                                      _selected = _find(id);
                                      _destinationId = id;
                                    }),
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
                              subtitle: 'Customize pace and copy directions',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Distance: ${_route!.totalDistanceKm.toStringAsFixed(2)} km',
                            ),
                            Text(
                              'Estimated walk: $_displayEstimatedMinutes min',
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
                                Expanded(
                                  child: Text(
                                    _selected!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
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
                            const SizedBox(height: 6),
                            Text(_selected!.description),
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
                            subtitle: 'Auto-updates from your GPS position',
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
                                title: Text(loc.name),
                                subtitle: Text(loc.type),
                                trailing: Text(
                                  loc.distanceMeters == null
                                      ? '-'
                                      : '${loc.distanceMeters!.round()} m',
                                ),
                                onTap: () => setState(() {
                                  _selected = _find(loc.id);
                                  _destinationId = loc.id;
                                }),
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
                                    onTap: () => setState(() {
                                      _selected = loc;
                                      _destinationId = loc.id;
                                    }),
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
                          label: const Text('Where am I?'),
                          onPressed: () => _sendMessage('Where am I?'),
                        ),
                        ActionChip(
                          label: const Text('Nearby places'),
                          onPressed: () => _sendMessage('Show nearby places'),
                        ),
                        ActionChip(
                          label: const Text('Library details'),
                          onPressed: () =>
                              _sendMessage('Tell me about library'),
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
                      'Flutter Android app for Smart Campus Navigation. '
                      'Uses backend APIs for locations, nearby, shortest route, and assistant chat. '
                      'Includes favorites, recent destinations, live map overlays, and copyable route summaries.',
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Backend for real Android phone: $phoneApiBaseUrl\n'
                      'Backend for emulator: $emulatorApiBaseUrl\n'
                      'Use settings icon to change API URL.',
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
