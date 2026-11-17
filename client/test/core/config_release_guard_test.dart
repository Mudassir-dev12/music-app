import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/config.dart' as config;

void main() {
  group('Release config guard', () {
    test('isProductionUrl detects loopback and invalid addresses', () {
      expect(config.isProductionUrl('http://127.0.0.1:8610'), isFalse);
      expect(config.isProductionUrl('http://localhost:8610'), isFalse);
      expect(config.isProductionUrl('http://10.0.2.2:8610'), isFalse);
      expect(config.isProductionUrl(''), isFalse);

      expect(config.isProductionUrl('https://music-api.example.com'), isTrue);
      expect(config.isProductionUrl('https://melodia.duckdns.org'), isTrue);
      expect(config.isProductionUrl('http://192.168.1.100:8610'), isTrue);
    });
  });
}

