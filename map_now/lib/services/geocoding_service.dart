import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/place_model.dart';

class GeocodingService {
  Future<List<PlaceModel>> searchAddress(String addressString) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.geocodingUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'addressString': addressString,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // API returns { "status": "success", "results": [...] }
        if (data['results'] != null && data['results'] is List) {
          return (data['results'] as List)
              .map((place) => PlaceModel.fromJson(place))
              .toList();
        } else if (data['fullAddress'] != null) {
          // If it returns a single place object
          return [PlaceModel.fromJson(data)];
        }
        
        return [];
      } else {
        throw Exception('Failed to search address. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
