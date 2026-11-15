import 'package:flutter/foundation.dart';

const _kDefaultPort = 8000;

String get _kDefaultHost {
  if (kIsWeb) return '127.0.0.1';
  if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return '127.0.0.1';
}

final String apiUrl = const String.fromEnvironment('API_URL').isNotEmpty
    ? const String.fromEnvironment('API_URL')
    : 'http://$_kDefaultHost:$_kDefaultPort';

const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Melodia');


