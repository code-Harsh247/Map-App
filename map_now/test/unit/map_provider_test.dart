import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:map_now/providers/map_provider.dart';
import 'package:map_now/models/place_model.dart';
import 'package:map_now/models/route_model.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../helpers/test_helper.mocks.dart';

// Mock Geolocator
class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    return Position(
      latitude: 52.0, longitude: 5.0, timestamp: DateTime.now(), 
      accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
  }
  
  @override
  Future<LocationAccuracyStatus> checkLocationAccuracyStatus() async => LocationAccuracyStatus.precise;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MapProvider mapProvider;
  late MockGeocodingService mockGeocodingService;
  late MockRoutingService mockRoutingService;

  setUp(() {
    mockGeocodingService = MockGeocodingService();
    mockRoutingService = MockRoutingService();
    
    // Assign Mock Geolocator
    GeolocatorPlatform.instance = MockGeolocatorPlatform();

    mapProvider = MapProvider(
      geocodingService: mockGeocodingService,
      routingService: mockRoutingService,
    );
  });

  group('MapProvider Tests', () {
    test('searchAddress success', () async {
      final places = [PlaceModel(fullAddress: '123 Test St', latitude: 10, longitude: 10, placeId: '1')];
      when(mockGeocodingService.searchAddress(any)).thenAnswer((_) async => places);

      await mapProvider.searchAddress('query');

      expect(mapProvider.searchResults, places);
      expect(mapProvider.isLoading, false);
    });

    test('findDirectRoute success', () async {
       final start = PlaceModel(fullAddress: 'Start', latitude: 10, longitude: 10, placeId: 's');
       final end = PlaceModel(fullAddress: 'End', latitude: 20, longitude: 20, placeId: 'e');
       final route = RouteModel(orderedCoordinates: [], path: [], distance: 100);
       
       mapProvider.setStartLocation(start);
       mapProvider.setDestination(end);
       
       when(mockRoutingService.getDirectRoute(start: anyNamed('start'), destination: anyNamed('destination')))
           .thenAnswer((_) async => route);
           
       await mapProvider.findDirectRoute();
       
       expect(mapProvider.optimizedRoute, route);
       expect(mapProvider.isLoading, false);
    });

    test('Add/Remove stops', () {
      final stop1 = PlaceModel(fullAddress: 'Stop1', latitude: 1, longitude: 1, placeId: '1');
      final stop2 = PlaceModel(fullAddress: 'Stop2', latitude: 2, longitude: 2, placeId: '2');

      mapProvider.addStop(stop1);
      expect(mapProvider.stops.length, 1);
      expect(mapProvider.stops.first, stop1);

      mapProvider.addStop(stop2);
      expect(mapProvider.stops.length, 2);

      mapProvider.removeStop(0);
      expect(mapProvider.stops.length, 1);
      expect(mapProvider.stops.first, stop2);
    });
    
    test('getUserLocation should update userLocation', () async {
       await mapProvider.getUserLocation();
       expect(mapProvider.userLocation?.latitude, 52.0);
       expect(mapProvider.userLocation?.longitude, 5.0);
       expect(mapProvider.errorMessage, null);
    });
  });
}
