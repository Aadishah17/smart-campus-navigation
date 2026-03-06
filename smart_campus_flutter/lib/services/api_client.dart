import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/campus_location.dart';
import '../models/route_result.dart';

class HealthInfo {
  const HealthInfo({
    required this.backendOnline,
    required this.databaseConnected,
    required this.databaseMode,
    required this.mongoConfigured,
    this.databaseError,
  });

  final bool backendOnline;
  final bool databaseConnected;
  final String databaseMode;
  final bool mongoConfigured;
  final String? databaseError;
}

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  static const _requestTimeout = Duration(seconds: 12);

  Future<HealthInfo> fetchHealthInfo() async {
    final response = await _send(() => http.get(_uri('/health')));
    if (response.statusCode != 200) {
      throw Exception('Backend health check failed (${response.statusCode}).');
    }

    final payload = _decodeObject(response.body);
    final database = (payload['database'] as Map<String, dynamic>?) ?? const {};

    return HealthInfo(
      backendOnline: payload['status'] == 'ok',
      databaseConnected: database['connected'] == true,
      databaseMode: database['mode']?.toString() ?? 'unknown',
      mongoConfigured: database['mongoConfigured'] == true,
      databaseError: database['lastError']?.toString(),
    );
  }

  Future<bool> healthCheck() async {
    final info = await fetchHealthInfo();
    return info.backendOnline;
  }

  Future<List<CampusLocation>> fetchLocations() async {
    final response = await _send(() => http.get(_uri('/locations')));
    _throwOnError(response);

    final payload = _decodeObject(response.body);
    final rawList = (payload['data'] as List<dynamic>? ?? const []);
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(CampusLocation.fromJson)
        .toList();
  }

  Future<RouteResult> fetchRoute({
    String? sourceId,
    required String destinationId,
    Position? sourcePosition,
  }) async {
    final body = <String, dynamic>{'destinationId': destinationId};

    if (sourcePosition != null) {
      body['sourcePosition'] = {
        'lat': sourcePosition.latitude,
        'lng': sourcePosition.longitude,
      };
    } else if (sourceId != null && sourceId.isNotEmpty) {
      body['sourceId'] = sourceId;
    }

    final response = await _send(
      () => http.post(
        _uri('/navigation/route'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    _throwOnError(response);
    return RouteResult.fromJson(_decodeObject(response.body));
  }

  Future<List<CampusLocation>> fetchNearby({
    required double lat,
    required double lng,
  }) async {
    final response = await _send(
      () => http.get(
        _uri('/navigation/nearby', {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radius': '1000',
          'limit': '8',
        }),
      ),
    );
    _throwOnError(response);

    final payload = _decodeObject(response.body);
    final rawList = (payload['data'] as List<dynamic>? ?? const []);
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(CampusLocation.fromJson)
        .toList();
  }

  Future<String> askAssistant({
    required String message,
    Position? position,
  }) async {
    final body = <String, dynamic>{'message': message};

    if (position != null) {
      body['userPosition'] = {
        'lat': position.latitude,
        'lng': position.longitude,
      };
    }

    final response = await _send(
      () => http.post(
        _uri('/assistant/chat'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    _throwOnError(response);
    final payload = _decodeObject(response.body);
    return payload['reply']?.toString() ?? 'No reply generated.';
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception('Request timed out. Check backend connectivity.');
    } on SocketException {
      throw Exception('Cannot reach backend. Check API URL and network.');
    } on http.ClientException catch (error) {
      throw Exception('Network error: ${error.message}');
    }
  }

  void _throwOnError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final payload = _decodeObject(response.body);
    final message = payload['message']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      throw Exception(message);
    }
    throw Exception('Request failed with status ${response.statusCode}.');
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) {
      return {};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }
}
