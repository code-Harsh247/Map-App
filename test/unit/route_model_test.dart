import 'package:flutter_test/flutter_test.dart';
import 'package:map_now/models/route_model.dart';

void main() {
  group('RouteModel', () {
    test('fromJson parses valid data correctly', () {
      final json = {
        'ordered_coordinates': [
          [10.0, 20.0],
          [30.0, 40.0],
        ],
        'path': [
          [10.0, 20.0],
          [15.0, 25.0],
          [30.0, 40.0],
        ],
        'distance': 5000.0,
      };

      final route = RouteModel.fromJson(json);

      expect(route.orderedCoordinates.length, 2);
      expect(route.orderedCoordinates[0], [10.0, 20.0]);
      expect(route.orderedCoordinates[1], [30.0, 40.0]);
      expect(route.path.length, 3);
      expect(route.distance, 5000.0);
      expect(route.distanceInKm, 5.0);
    });

    test('fromJson handles null coordinates gracefully', () {
      final json = {
        'ordered_coordinates': null,
        'path': null,
        'distance': null,
      };

      final route = RouteModel.fromJson(json);

      expect(route.orderedCoordinates, isEmpty);
      expect(route.path, isEmpty);
      expect(route.distance, 0.0);
    });

    test('fromJson handles empty lists', () {
      final json = {
        'ordered_coordinates': [],
        'path': [],
        'distance': 0.0,
      };

      final route = RouteModel.fromJson(json);

      expect(route.orderedCoordinates, isEmpty);
      expect(route.path, isEmpty);
    });

    test('fromJson handles malformed coord with fewer than 2 elements', () {
      final json = {
        'ordered_coordinates': [
          [10.0], // Only 1 element — should not crash
        ],
        'path': [
          [], // Empty list — should not crash
          [5.0], // 1 element — should not crash
          [10.0, 20.0], // Valid
        ],
        'distance': 100.0,
      };

      final route = RouteModel.fromJson(json);

      // Malformed coords should default to [0.0, 0.0]
      expect(route.orderedCoordinates[0], [0.0, 0.0]);
      expect(route.path[0], [0.0, 0.0]);
      expect(route.path[1], [0.0, 0.0]);
      expect(route.path[2], [10.0, 20.0]);
    });

    test('fromJson handles non-list coord items gracefully', () {
      final json = {
        'ordered_coordinates': [
          'not a list',
          42,
          null,
        ],
        'path': [],
        'distance': 0.0,
      };

      final route = RouteModel.fromJson(json);

      // Non-list items should return [0.0, 0.0]
      expect(route.orderedCoordinates.length, 3);
      for (var coord in route.orderedCoordinates) {
        expect(coord, [0.0, 0.0]);
      }
    });

    test('fromJson handles integer coordinates (num to double)', () {
      final json = {
        'ordered_coordinates': [
          [10, 20], // integers instead of doubles
        ],
        'path': [],
        'distance': 1000,
      };

      final route = RouteModel.fromJson(json);

      expect(route.orderedCoordinates[0], [10.0, 20.0]);
      expect(route.distance, 1000.0);
      expect(route.distanceInKm, 1.0);
    });

    test('toJson serializes correctly', () {
      final route = RouteModel(
        orderedCoordinates: [
          [10.0, 20.0]
        ],
        path: [
          [10.0, 20.0],
          [30.0, 40.0]
        ],
        distance: 5000.0,
      );

      final json = route.toJson();

      expect(json['ordered_coordinates'], [
        [10.0, 20.0]
      ]);
      expect(json['path'], [
        [10.0, 20.0],
        [30.0, 40.0]
      ]);
      expect(json['distance'], 5000.0);
    });

    test('distanceInKm converts meters to kilometers', () {
      final route = RouteModel(
        orderedCoordinates: [],
        path: [],
        distance: 12345.0,
      );

      expect(route.distanceInKm, closeTo(12.345, 0.001));
    });

    test('distanceInKm with zero distance', () {
      final route = RouteModel(
        orderedCoordinates: [],
        path: [],
        distance: 0.0,
      );

      expect(route.distanceInKm, 0.0);
    });
  });
}
