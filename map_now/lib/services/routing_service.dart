import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/route_model.dart';

class RoutingService {
  /// Call the routing API with exactly 2 or more coordinate pairs.
  /// Each coordinate is [latitude, longitude].
  Future<RouteModel?> _callRoutingApi(List<List<double>> coordinates) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.multiStopUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'coordinates': coordinates,
          'Cache': true,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return RouteModel.fromJson(data);
      } else {
        throw Exception('Failed to get route. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Routing error: $e');
    }
  }

  /// Get a direct route between start and destination (2 points).
  Future<RouteModel?> getDirectRoute({
    required List<double> start,
    required List<double> destination,
  }) async {
    return _callRoutingApi([start, destination]);
  }

  /// Get a chained route: start → stop1 → stop2 → ... → destination.
  /// Calls the API for each consecutive pair and combines the paths.
  /// This is the DEFAULT behavior when user adds stops (no optimization).
  Future<RouteModel?> getChainedRoute({
    required List<double> start,
    required List<List<double>> stops,
    required List<double> destination,
  }) async {
    // Build all waypoints in order
    final waypoints = [start, ...stops, destination];

    List<List<double>> combinedPath = [];
    double totalDistance = 0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final segment = await _callRoutingApi([waypoints[i], waypoints[i + 1]]);
      if (segment == null) {
        throw Exception('Failed to get route for segment ${i + 1}');
      }
      combinedPath.addAll(segment.path);
      totalDistance += segment.distance;
    }

    return RouteModel(
      orderedCoordinates: waypoints,
      path: combinedPath,
      distance: totalDistance,
    );
  }

  /// Get an optimized route for all points.
  /// Calls the API with all points at once, allowing the backend to reorder if needed.
  Future<RouteModel?> getOptimizedRoute({
    required List<double> start,
    required List<List<double>> stops,
    required List<double> destination,
  }) async {
    // Pass everything to the backend to optimize
    return _callRoutingApi([start, ...stops, destination]);
  }
}
