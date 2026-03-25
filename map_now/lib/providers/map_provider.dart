import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';
import '../models/route_model.dart';
import '../services/geocoding_service.dart';
import '../services/routing_service.dart';

class MapProvider extends ChangeNotifier {
  final GeocodingService _geocodingService;
  final RoutingService _routingService;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  MapProvider({GeocodingService? geocodingService, RoutingService? routingService})
      : _geocodingService = geocodingService ?? GeocodingService(),
        _routingService = routingService ?? RoutingService();

  MapController? _mapController;
  PlaceModel? _startLocation;
  PlaceModel? _destination;
  final List<PlaceModel> _stops = [];
  RouteModel? _optimizedRoute;
  bool _isLoading = false;
  String? _errorMessage;
  List<PlaceModel> _searchResults = [];

  // User location
  LatLng? _userLocation;
  bool _locationLoading = false;
  
  // Authentication token
  String? _token;

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
  bool get canAddMoreStops => _stops.length < 5;
  bool get canOptimizeRoute => _startLocation != null && _destination != null;

  // Track whether stops have changed since last optimization
  bool _stopsNeedOptimization = false;
  bool get stopsNeedOptimization => _stopsNeedOptimization && _stops.isNotEmpty;

  /// Check if the user's current location matches either start or destination
  /// within a tolerance of 50 meters
  bool get isUserLocationPartOfRoute {
    if (_userLocation == null) return false;
    
    const double toleranceInMeters = 50.0;
    
    // Check if user location matches start location
    if (_startLocation != null) {
      final startDistance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        _startLocation!.latitude,
        _startLocation!.longitude,
      );
      if (startDistance <= toleranceInMeters) return true;
    }
    
    // Check if user location matches destination
    if (_destination != null) {
      final destDistance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );
      if (destDistance <= toleranceInMeters) return true;
    }
    
    return false;
  }

  void setMapController(MapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void setToken(String? token) {
    _token = token;
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
    if (_stops.length < 5) {
      _stops.add(place);
      _stopsNeedOptimization = true;
      notifyListeners();
    } else {
      _errorMessage = 'Maximum of 5 stops allowed.';
      notifyListeners();
      // Auto-clear helper
      Future.delayed(const Duration(seconds: 3), () {
        if (_errorMessage == 'Maximum of 5 stops allowed.') {
          _errorMessage = null;
          notifyListeners();
        }
      });
    }
  }

  void removeStop(int index) {
    if (index >= 0 && index < _stops.length) {
      _stops.removeAt(index);
      _stopsNeedOptimization = _stops.isNotEmpty;
      notifyListeners();
    }
  }

  void clearStops() {
    _stops.clear();
    notifyListeners();
  }

  void reorderStops(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _stops.removeAt(oldIndex);
    _stops.insert(newIndex, item);
    _stopsNeedOptimization = true;
    notifyListeners();
  }

  /// Reorders the full list of waypoints: [Start, ...Stops, Destination]
  void reorderWaypoints(int oldIndex, int newIndex) {
    if (_startLocation == null || _destination == null) return;
    
    // Construct full list
    List<PlaceModel> allPoints = [_startLocation!, ..._stops, _destination!];
    
    // Apply reorder
    if (newIndex > oldIndex) newIndex--;
    // Check bounds
    if (oldIndex < 0 || oldIndex >= allPoints.length) return;
    if (newIndex < 0 || newIndex >= allPoints.length) return; // Should insert at end? No, newIndex is position.
    
    final item = allPoints.removeAt(oldIndex);
    allPoints.insert(newIndex, item);
    
    // Deconstruct back to Start, Stops, Destination
    _startLocation = allPoints.first;
    _destination = allPoints.last;
    
    // Middleware points are the new stops
    if (allPoints.length > 2) {
      _stops.clear();
      _stops.addAll(allPoints.sublist(1, allPoints.length - 1));
    } else {
      _stops.clear();
    }
    
    _stopsNeedOptimization = true;
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

  /// Call routing API for a direct start → destination path (no intermediate stops).
  Future<void> findDirectRoute() async {
    if (_startLocation == null || _destination == null) {
      _errorMessage = 'Please set start location and destination';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final route = await _routingService.getDirectRoute(
        start: _startLocation!.toLatLngArray(),
        destination: _destination!.toLatLngArray(),
      );

      _optimizedRoute = route;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Routing failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculates the route by chaining segments (Start -> A -> B -> End).
  /// Does NOT optimize order. Use this when stops are added/moved manually.
  Future<void> calculateChainedRoute() async {
    if (_startLocation == null || _destination == null) {
      _errorMessage = 'Please set start location and destination';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final route = await _routingService.getChainedRoute(
        start: _startLocation!.toLatLngArray(),
        stops: _stops.map((s) => s.toLatLngArray()).toList(),
        destination: _destination!.toLatLngArray(),
      );

      _optimizedRoute = route;
      // We still flagging true, because it's just chained, not "optimized" by server
      _stopsNeedOptimization = true; 
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Route calculation failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Optimize the route using the backend API (reorders stops for best path).
  Future<void> optimizeRoute() async {
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
        start: _startLocation!.toLatLngArray(),
        stops: _stops.map((s) => s.toLatLngArray()).toList(),
        destination: _destination!.toLatLngArray(),
      );

      _optimizedRoute = route;
      _stopsNeedOptimization = false;
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
    _stopsNeedOptimization = false;
    notifyListeners();
  }
}
