import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class AuthService {
  // Demo-friendly login with real API call but graceful fallback
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

      // Try real API call first
      try {
        final response = await http.post(
          Uri.parse(ApiConstants.loginUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name.trim(),
            'mobile': mobile.trim(),
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'data': data,
            'source': 'api'
          };
        } else {
          // API failed but don't block user in demo mode
          print('Login API failed with status: ${response.statusCode}');
          return _fallbackLogin(name.trim(), mobile.trim());
        }
      } catch (e) {
        // Network error or timeout - fallback to demo mode so user isn't blocked
        print('Login API error: $e - falling back to demo mode');
        return _fallbackLogin(name.trim(), mobile.trim());
      }
    } catch (e) {
      // Final fallback - ensures user isn't blocked even in unexpected scenarios
      return _fallbackLogin(name.trim(), mobile.trim());
    }
  }

  // Demo fallback when API is unavailable - allows user to continue
  Map<String, dynamic> _fallbackLogin(String name, String mobile) {
    return {
      'success': true,
      'data': {
        'message': 'Login successful (Demo mode - API unavailable)',
        'user': {
          'name': name,
          'mobile': mobile,
          'userId': 'demo_${DateTime.now().millisecondsSinceEpoch}',
        },
      },
      'source': 'demo'
    };
  }
}
