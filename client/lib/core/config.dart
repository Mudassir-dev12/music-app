import 'package:flutter/foundation.dart';

const _kRawApiUrl = String.fromEnvironment('API_URL');

String _configuredApiUrl = _kRawApiUrl.isNotEmpty
    ? _kRawApiUrl
    : 'https://music.muhammadrehan-dev.me';

String get apiUrl => _configuredApiUrl;

void setApiUrl(String newUrl) {
  _configuredApiUrl = newUrl;
}

const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Melodia');

/// Validates whether a URL is a non-loopback production server URL.
bool isProductionUrl(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  if (host == '127.0.0.1' || host == 'localhost' || host == '10.0.2.2' || host.isEmpty) {
    return false;
  }
  return true;
}

/// Returns true if this build is properly configured with a production server URL in release mode.
bool get isReleaseConfigured {
  if (!kReleaseMode) return true;
  return isProductionUrl(_configuredApiUrl);
}
