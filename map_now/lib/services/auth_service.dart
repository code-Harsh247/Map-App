import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class AuthService {
  // Real login API call
  Future<Map<String, dynamic>> login(String name, String mobile) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        return {
          'success': false,
          'error': 'Name is required',
        };
      }

      if (mobile.trim().isEmpty || mobile.trim().length < 10) {
        return {
          'success': false,
          'error': 'Valid mobile number is required',
        };
      }

      try {
        final response = await http.post(
          Uri.parse('https://maps.amphereai.com/api/login/route'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name.trim(),
            'mobile': mobile.trim(),
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'data': data,
          };
        } else {
          // If server returns error, we might want to fallback to mock for demo
          // But strict error handling is better. 
          // However, user said "failsafe". Let's try mock if server fails?
          // Actually, let's just return the error gracefully.
          String errorMsg = 'Login failed';
          try {
            final errorData = jsonDecode(response.body);
            errorMsg = errorData['message'] ?? errorData['error'] ?? 'Login failed';
          } catch (_) {}
          
          return {
            'success': false,
            'error': '$errorMsg (Code: ${response.statusCode})',
          };
        }
      } catch (e) {
        return {
          'success': false,
          'error': 'Network error or server unreachable: $e',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'An unexpected error occurred: $e',
      };
    }
  }
}
