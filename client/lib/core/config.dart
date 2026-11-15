import 'package:flutter/foundation.dart';

const _kDefaultPort = 8000;

String get _kDefaultHost {
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    return '127.0.0.1';
  }
  // On mobile devices (Android / iOS): connect to computer's Wi-Fi LAN IP
  return '192.168.0.104';
}

String _configuredApiUrl = const String.fromEnvironment('API_URL').isNotEmpty
    ? const String.fromEnvironment('API_URL')
    : 'http://$_kDefaultHost:$_kDefaultPort';

String get apiUrl => _configuredApiUrl;

void setApiUrl(String newUrl) {
  _configuredApiUrl = newUrl;
}

const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Melodia');




