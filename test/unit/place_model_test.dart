import 'package:flutter_test/flutter_test.dart';
import 'package:map_now/models/place_model.dart';

void main() {
  group('PlaceModel', () {
    test('fromJson parses valid data correctly', () {
      final json = {
        'fullAddress': '123 Main St, City',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'placeId': 'place_123',
      };

      final place = PlaceModel.fromJson(json);

      expect(place.fullAddress, '123 Main St, City');
      expect(place.latitude, 12.9716);
      expect(place.longitude, 77.5946);
      expect(place.placeId, 'place_123');
    });

    test('fromJson handles null values with defaults', () {
      final json = <String, dynamic>{};

      final place = PlaceModel.fromJson(json);

      expect(place.fullAddress, '');
      expect(place.latitude, 0.0);
      expect(place.longitude, 0.0);
      expect(place.placeId, '');
    });

    test('fromJson handles integer lat/lng', () {
      final json = {
        'fullAddress': 'Test Address',
        'latitude': 10,
        'longitude': 20,
        'placeId': 'id',
      };

      final place = PlaceModel.fromJson(json);

      expect(place.latitude, 10.0);
      expect(place.longitude, 20.0);
    });

    test('toJson serializes correctly', () {
      final place = PlaceModel(
        fullAddress: 'Test St',
        latitude: 10.5,
        longitude: 20.5,
        placeId: 'p1',
      );

      final json = place.toJson();

      expect(json['fullAddress'], 'Test St');
      expect(json['latitude'], 10.5);
      expect(json['longitude'], 20.5);
      expect(json['placeId'], 'p1');
    });

    test('toCoordinate returns correct map', () {
      final place = PlaceModel(
        fullAddress: 'Test',
        latitude: 12.0,
        longitude: 34.0,
        placeId: 'x',
      );

      final coord = place.toCoordinate();

      expect(coord['latitude'], 12.0);
      expect(coord['longitude'], 34.0);
    });

    test('toLatLngArray returns correct list', () {
      final place = PlaceModel(
        fullAddress: 'Test',
        latitude: 12.0,
        longitude: 34.0,
        placeId: 'x',
      );

      final arr = place.toLatLngArray();

      expect(arr, [12.0, 34.0]);
    });

    test('roundtrip fromJson/toJson preserves data', () {
      final original = PlaceModel(
        fullAddress: 'Round Trip Test',
        latitude: 45.678,
        longitude: -90.123,
        placeId: 'rt_1',
      );

      final json = original.toJson();
      final restored = PlaceModel.fromJson(json);

      expect(restored.fullAddress, original.fullAddress);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.placeId, original.placeId);
    });
  });
}
