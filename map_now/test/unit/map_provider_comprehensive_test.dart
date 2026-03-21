import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:map_now/providers/map_provider.dart';
import 'package:map_now/models/place_model.dart';
import 'package:map_now/models/route_model.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../helpers/test_helper.mocks.dart';

// Mock Geolocator for location tests
class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool locationServiceEnabled = true;
  LocationPermission permission = LocationPermission.always;

  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<bool> isLocationServiceEnabled() async => locationServiceEnabled;
  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    return Position(
      latitude: 52.0,
      longitude: 5.0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  @override
  Future<LocationAccuracyStatus> checkLocationAccuracyStatus() async =>
      LocationAccuracyStatus.precise;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlaceModel _place(String name, double lat, double lng, [String? id]) =>
    PlaceModel(
      fullAddress: name,
      latitude: lat,
      longitude: lng,
      placeId: id ?? name.toLowerCase().replaceAll(' ', '_'),
    );

void main() {
  late MapProvider provider;
  late MockGeocodingService mockGeocoding;
  late MockRoutingService mockRouting;
  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeocoding = MockGeocodingService();
    mockRouting = MockRoutingService();
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;

    // Provide dummy values for non-nullable types used by Mockito
    provideDummy<List<double>>(<double>[]);
    provideDummy<List<List<double>>>(<List<double>>[]);

    provider = MapProvider(
      geocodingService: mockGeocoding,
      routingService: mockRouting,
    );
  });

  group('Initial state', () {
    test('has correct defaults', () {
      expect(provider.startLocation, isNull);
      expect(provider.destination, isNull);
      expect(provider.stops, isEmpty);
      expect(provider.optimizedRoute, isNull);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
      expect(provider.searchResults, isEmpty);
      expect(provider.userLocation, isNull);
      expect(provider.stopCount, 0);
      expect(provider.canAddMoreStops, true);
      expect(provider.canOptimizeRoute, false);
      expect(provider.stopsNeedOptimization, false);
    });
  });

  group('Set locations', () {
    test('setStartLocation updates start', () {
      final place = _place('Start', 10, 20);
      provider.setStartLocation(place);
      expect(provider.startLocation, place);
    });

    test('setDestination updates destination', () {
      final place = _place('End', 30, 40);
      provider.setDestination(place);
      expect(provider.destination, place);
    });

    test('canOptimizeRoute is true when both set', () {
      provider.setStartLocation(_place('A', 1, 1));
      provider.setDestination(_place('B', 2, 2));
      expect(provider.canOptimizeRoute, true);
    });
  });

  group('Stops management', () {
    test('addStop adds to list', () {
      provider.addStop(_place('S1', 1, 1));
      expect(provider.stops.length, 1);
      expect(provider.stopCount, 1);
    });

    test('addStop limits to 5 stops', () {
      for (int i = 0; i < 5; i++) {
        provider.addStop(_place('S$i', i.toDouble(), i.toDouble()));
      }
      expect(provider.stops.length, 5);
      expect(provider.canAddMoreStops, false);

      // Adding a 6th should not increase count
      provider.addStop(_place('S6', 6, 6));
      expect(provider.stops.length, 5);
      expect(provider.errorMessage, 'Maximum of 5 stops allowed.');
    });

    test('removeStop removes correct stop', () {
      provider.addStop(_place('S1', 1, 1));
      provider.addStop(_place('S2', 2, 2));
      provider.removeStop(0);
      expect(provider.stops.length, 1);
      expect(provider.stops.first.fullAddress, 'S2');
    });

    test('removeStop with invalid index does nothing', () {
      provider.addStop(_place('S1', 1, 1));
      provider.removeStop(-1);
      expect(provider.stops.length, 1);
      provider.removeStop(5);
      expect(provider.stops.length, 1);
    });

    test('clearStops empties the list', () {
      provider.addStop(_place('S1', 1, 1));
      provider.addStop(_place('S2', 2, 2));
      provider.clearStops();
      expect(provider.stops, isEmpty);
    });

    test('reorderStops moves items correctly', () {
      provider.addStop(_place('A', 1, 1));
      provider.addStop(_place('B', 2, 2));
      provider.addStop(_place('C', 3, 3));
      provider.reorderStops(0, 2);
      expect(provider.stops[0].fullAddress, 'B');
      expect(provider.stops[1].fullAddress, 'A');
      expect(provider.stops[2].fullAddress, 'C');
    });

    test('stopsNeedOptimization flag', () {
      expect(provider.stopsNeedOptimization, false);
      provider.addStop(_place('S1', 1, 1));
      expect(provider.stopsNeedOptimization, true);
      provider.removeStop(0);
      expect(provider.stopsNeedOptimization, false);
    });
  });

  group('Reorder waypoints', () {
    test('reorderWaypoints swaps start and destination', () {
      provider.setStartLocation(_place('Start', 1, 1));
      provider.setDestination(_place('End', 2, 2));

      // In ReorderableListView convention, newIndex=2 means "after last item"
      // which effectively swaps in a 2-item list
      provider.reorderWaypoints(0, 2);

      expect(provider.startLocation!.fullAddress, 'End');
      expect(provider.destination!.fullAddress, 'Start');
    });

    test('reorderWaypoints moves stop to start', () {
      provider.setStartLocation(_place('Start', 1, 1));
      provider.addStop(_place('Mid', 5, 5));
      provider.setDestination(_place('End', 2, 2));

      // Move the stop (index 1) to position 0 (start)
      provider.reorderWaypoints(1, 0);

      expect(provider.startLocation!.fullAddress, 'Mid');
      expect(provider.stops.first.fullAddress, 'Start');
      expect(provider.destination!.fullAddress, 'End');
    });

    test('reorderWaypoints does nothing without start/destination', () {
      provider.reorderWaypoints(0, 1);
      // Should not crash
      expect(provider.startLocation, isNull);
    });
  });

  group('Search', () {
    test('searchAddress success updates results', () async {
      final places = [_place('Result', 10, 10)];
      when(mockGeocoding.searchAddress(any)).thenAnswer((_) async => places);

      await provider.searchAddress('test');

      expect(provider.searchResults, places);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('searchAddress with empty query clears results', () async {
      await provider.searchAddress('');
      expect(provider.searchResults, isEmpty);
    });

    test('searchAddress error sets errorMessage', () async {
      when(mockGeocoding.searchAddress(any))
          .thenThrow(Exception('Network error'));

      await provider.searchAddress('fail');

      expect(provider.searchResults, isEmpty);
      expect(provider.errorMessage, contains('Search failed'));
      expect(provider.isLoading, false);
    });
  });

  group('Direct route', () {
    test('findDirectRoute success', () async {
      provider.setStartLocation(_place('A', 10, 10));
      provider.setDestination(_place('B', 20, 20));

      final route =
          RouteModel(orderedCoordinates: [], path: [], distance: 5000);
      when(mockRouting.getDirectRoute(
        start: anyNamed('start'),
        destination: anyNamed('destination'),
      )).thenAnswer((_) async => route);

      await provider.findDirectRoute();

      expect(provider.optimizedRoute, route);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('findDirectRoute without locations sets error', () async {
      await provider.findDirectRoute();
      expect(provider.errorMessage, 'Please set start location and destination');
    });

    test('findDirectRoute error sets errorMessage', () async {
      provider.setStartLocation(_place('A', 10, 10));
      provider.setDestination(_place('B', 20, 20));

      when(mockRouting.getDirectRoute(
        start: anyNamed('start'),
        destination: anyNamed('destination'),
      )).thenThrow(Exception('API down'));

      await provider.findDirectRoute();

      expect(provider.errorMessage, contains('Routing failed'));
      expect(provider.isLoading, false);
    });
  });

  group('Chained route', () {
    test('calculateChainedRoute success', () async {
      provider.setStartLocation(_place('A', 10, 10));
      provider.addStop(_place('Mid', 15, 15));
      provider.setDestination(_place('B', 20, 20));

      final route =
          RouteModel(orderedCoordinates: [], path: [], distance: 8000);
      when(mockRouting.getChainedRoute(
        start: anyNamed('start'),
        stops: anyNamed('stops'),
        destination: anyNamed('destination'),
      )).thenAnswer((_) async => route);

      await provider.calculateChainedRoute();

      expect(provider.optimizedRoute, route);
      expect(provider.isLoading, false);
    });

    test('calculateChainedRoute without locations sets error', () async {
      await provider.calculateChainedRoute();
      expect(provider.errorMessage, 'Please set start location and destination');
    });
  });

  group('Optimize route', () {
    test('optimizeRoute success clears optimization flag', () async {
      provider.setStartLocation(_place('A', 10, 10));
      provider.addStop(_place('Mid', 15, 15));
      provider.setDestination(_place('B', 20, 20));

      expect(provider.stopsNeedOptimization, true);

      final route =
          RouteModel(orderedCoordinates: [], path: [], distance: 7000);
      when(mockRouting.getOptimizedRoute(
        start: anyNamed('start'),
        stops: anyNamed('stops'),
        destination: anyNamed('destination'),
      )).thenAnswer((_) async => route);

      await provider.optimizeRoute();

      expect(provider.optimizedRoute, route);
      expect(provider.stopsNeedOptimization, false);
    });
  });

  group('User location', () {
    test('getUserLocation success', () async {
      await provider.getUserLocation();
      expect(provider.userLocation?.latitude, 52.0);
      expect(provider.userLocation?.longitude, 5.0);
      expect(provider.errorMessage, isNull);
    });

    test('getUserLocation with services disabled', () async {
      mockGeolocator.locationServiceEnabled = false;
      await provider.getUserLocation();
      expect(provider.errorMessage,
          'Location services are disabled. Please enable GPS.');
      expect(provider.userLocation, isNull);
    });

    test('getUserLocation with denied permission', () async {
      mockGeolocator.permission = LocationPermission.deniedForever;
      await provider.getUserLocation();
      expect(provider.errorMessage, contains('permanently denied'));
    });
  });

  group('Reset', () {
    test('reset clears all state', () {
      provider.setStartLocation(_place('A', 1, 1));
      provider.setDestination(_place('B', 2, 2));
      provider.addStop(_place('S', 3, 3));

      provider.reset();

      expect(provider.startLocation, isNull);
      expect(provider.destination, isNull);
      expect(provider.stops, isEmpty);
      expect(provider.optimizedRoute, isNull);
      expect(provider.searchResults, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.stopsNeedOptimization, false);
    });
  });

  group('Dispose safety', () {
    test('notifyListeners after dispose does not crash', () {
      provider.setStartLocation(_place('A', 1, 1));
      provider.dispose();

      // This should not throw
      expect(() {
        // Simulate the delayed callback that was the original bug
        provider.addStop(_place('X', 0, 0)); // internally calls notifyListeners
      }, returnsNormally);
    });
  });
}
