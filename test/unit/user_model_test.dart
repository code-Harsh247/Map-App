import 'package:flutter_test/flutter_test.dart';
import 'package:map_now/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('constructor sets fields correctly', () {
      final user = UserModel(name: 'Test User', mobile: '1234567890');
      expect(user.name, 'Test User');
      expect(user.mobile, '1234567890');
    });

    test('fromJson parses correctly', () {
      final json = {'name': 'John', 'mobile': '9876543210'};
      final user = UserModel.fromJson(json);
      expect(user.name, 'John');
      expect(user.mobile, '9876543210');
    });

    test('toJson serializes correctly', () {
      final user = UserModel(name: 'Jane', mobile: '5555555555');
      final json = user.toJson();
      expect(json['name'], 'Jane');
      expect(json['mobile'], '5555555555');
    });

    test('roundtrip fromJson/toJson', () {
      final original = UserModel(name: 'Round', mobile: '1111111111');
      final restored = UserModel.fromJson(original.toJson());
      expect(restored.name, original.name);
      expect(restored.mobile, original.mobile);
    });
  });
}
