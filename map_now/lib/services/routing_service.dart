import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/route_model.dart';

class RoutingService {
  Future<RouteModel?> getOptimizedRoute({
    required Map<String, double> start,
    required List<Map<String, double>> stops,
    required Map<String, double> destination,
  }) async {
    try {
      // Validate: Maximum 3 stops allowed
      if (stops.length > 3) {
        throw Exception('Maximum 3 intermediate stops allowed');
      }

      // Build coordinates array: Start + Stops + Destination
      List<Map<String, double>> coordinates = [
        start,
        ...stops,
        destination,
      ];

      final response = await http.post(
        Uri.parse(ApiConstants.multiStopUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'coordinates': coordinates,
          'cache': true, // Enable caching for frequent routes
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
}
