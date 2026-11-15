const _kDefaultPort = 8000;

String get _kDefaultHost => '127.0.0.1';

final String apiUrl = const String.fromEnvironment('API_URL').isNotEmpty
    ? const String.fromEnvironment('API_URL')
    : 'http://$_kDefaultHost:$_kDefaultPort';

const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Melodia');



