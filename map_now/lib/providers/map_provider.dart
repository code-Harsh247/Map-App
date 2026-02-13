import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';
import '../models/route_model.dart';
import '../services/geocoding_service.dart';
import '../services/routing_service.dart';

class MapProvider extends ChangeNotifier {
  final GeocodingService _geocodingService = GeocodingService();
  final RoutingService _routingService = RoutingService();

  MapController? _mapController;
  PlaceModel? _startLocation;
  PlaceModel? _destination;
  List<PlaceModel> _stops = [];
  RouteModel? _optimizedRoute;
  bool _isLoading = false;
  String? _errorMessage;
  List<PlaceModel> _searchResults = [];

  // User location
  LatLng? _userLocation;
  bool _locationLoading = false;

  // Getters
  MapController? get mapController => _mapController;
  PlaceModel? get startLocation => _startLocation;
  PlaceModel? get destination => _destination;
  List<PlaceModel> get stops => _stops;
  RouteModel? get optimizedRoute => _optimizedRoute;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<PlaceModel> get searchResults => _searchResults;
  LatLng? get userLocation => _userLocation;
  bool get locationLoading => _locationLoading;
  
  int get stopCount => _stops.length;
  bool get canAddMoreStops => _stops.length < 3;
  bool get canOptimizeRoute => _startLocation != null && _destination != null;

  void setMapController(MapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  /// Request permission and get the user's current GPS location.
  /// Centers the map on the location once obtained.
  Future<void> getUserLocation() async {
    _locationLoading = true;
    notifyListeners();

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled. Please enable GPS.';
        _locationLoading = false;
        notifyListeners();
        return;
      }

      // Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permission denied.';
          _locationLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _errorMessage =
            'Location permission permanently denied. Please enable it in settings.';
        _locationLoading = false;
        notifyListeners();
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _userLocation = LatLng(position.latitude, position.longitude);
      _errorMessage = null;

      // Move the map to the user's location
      _mapController?.move(_userLocation!, 15);

      _locationLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to get location: $e';
      _locationLoading = false;
      notifyListeners();
    }
  }

  void setStartLocation(PlaceModel place) {
    _startLocation = place;
    notifyListeners();
  }

  void setDestination(PlaceModel place) {
    _destination = place;
    notifyListeners();
  }

  void addStop(PlaceModel place) {
    if (_stops.length < 3) {
      _stops.add(place);
      notifyListeners();
    }
  }

  void removeStop(int index) {
    if (index >= 0 && index < _stops.length) {
      _stops.removeAt(index);
      notifyListeners();
    }
  }

  void clearStops() {
    _stops.clear();
    notifyListeners();
  }

  void clearRoute() {
    _optimizedRoute = null;
    notifyListeners();
  }

  Future<void> searchAddress(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _geocodingService.searchAddress(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Search failed: $e';
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> findOptimizedRoute() async {
    if (_startLocation == null || _destination == null) {
      _errorMessage = 'Please set start location and destination';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final route = await _routingService.getOptimizedRoute(
        start: _startLocation!.toCoordinate(),
        stops: _stops.map((stop) => stop.toCoordinate()).toList(),
        destination: _destination!.toCoordinate(),
      );

      _optimizedRoute = route;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Route optimization failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _startLocation = null;
    _destination = null;
    _stops.clear();
    _optimizedRoute = null;
    _searchResults = [];
    _errorMessage = null;
    notifyListeners();
  }
}
