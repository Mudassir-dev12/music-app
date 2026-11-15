import 'package:flutter/foundation.dart';

const _kDefaultApiUrl = kIsWeb
    ? 'http://127.0.0.1:8610'
    : 'http://10.0.2.2:8610';

const apiUrl = String.fromEnvironment('API_URL', defaultValue: _kDefaultApiUrl);
const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Melodia');
