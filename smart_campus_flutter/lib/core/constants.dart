import 'package:flutter/foundation.dart';

const String emulatorApiBaseUrl = 'http://10.0.2.2:5050/api';
const String usbDebugApiBaseUrl = 'http://127.0.0.1:5050/api';
const String phoneApiBaseUrl = 'http://192.168.1.44:5050/api';
const String desktopWebApiBaseUrl = 'http://127.0.0.1:5050/api';
final String defaultApiBaseUrl = switch (defaultTargetPlatform) {
  TargetPlatform.android => phoneApiBaseUrl,
  _ when kIsWeb => desktopWebApiBaseUrl,
  _ => desktopWebApiBaseUrl,
};
const String apiBaseUrlPrefKey = 'api_base_url';
const String favoriteLocationIdsPrefKey = 'favorite_location_ids';
const String recentDestinationIdsPrefKey = 'recent_destination_ids';
