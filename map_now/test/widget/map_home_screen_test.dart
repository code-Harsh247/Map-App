import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_now/screens/map_home_screen.dart';
import 'package:provider/provider.dart';
import 'package:map_now/providers/auth_provider.dart';
import 'package:map_now/providers/map_provider.dart';
import '../helpers/test_helper.mocks.dart';
import '../helpers/mock_geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'dart:io';
import 'dart:async';


// Mock Http Client to avoid 400 errors from tile loading
class MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => MockHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => MockHttpClientRequest();
  
  @override
  bool autoUncompress = true;
  
  @override
  void close({bool force = false}) {}
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse();
    @override
  HttpHeaders get headers => MockHttpHeaders();
}

class MockHttpHeaders extends Fake implements HttpHeaders {
    @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
      return Stream<List<int>>.value([0]).listen(onData, onError: onError, onDone: onDone);
  }
  @override
  int get contentLength => 1;
}

void main() {
  late MockAuthService mockAuthService;
  late MockGeocodingService mockGeocodingService;
  late MockRoutingService mockRoutingService;
  late AuthProvider authProvider;
  late MapProvider mapProvider;

  setUp(() {
    mockAuthService = MockAuthService();
    mockGeocodingService = MockGeocodingService();
    mockRoutingService = MockRoutingService();
    
    GeolocatorPlatform.instance = MockGeolocatorPlatform();
    
    authProvider = AuthProvider(authService: mockAuthService);
    mapProvider = MapProvider(
        geocodingService: mockGeocodingService, 
        routingService: mockRoutingService
    );
  });

  testWidgets('MapHomeScreen renders map and UI elements', (WidgetTester tester) async {
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<MapProvider>.value(value: mapProvider),
            ],
            child: const MaterialApp(home: MapHomeScreen()),
          ),
        );
        
        await tester.pump(); 
        
        expect(find.byIcon(Icons.menu), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);
      },
      createHttpClient: (_) => MockHttpClient(),
    );
  });
}
