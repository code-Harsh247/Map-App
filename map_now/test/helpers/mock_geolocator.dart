import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
