// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../constants/api_constants.dart';

class AuthService {
  // Mock login - credentials will be stored in SharedPreferences by AuthProvider
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

      // Mock API delay to simulate network call
      await Future.delayed(const Duration(milliseconds: 800));

      // Mock successful response
      return {
        'success': true,
        'data': {
          'message': 'Login successful',
          'user': {
            'name': name,
            'mobile': mobile,
            'userId': 'mock_${DateTime.now().millisecondsSinceEpoch}',
          },
        },
      };

      /* 
      // Real API call (currently disabled)
      final response = await http.post(
        Uri.parse(ApiConstants.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'mobile': mobile,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to login. Status: ${response.statusCode}',
        };
      }
      */
    } catch (e) {
      return {
        'success': false,
        'error': 'Login error: $e',
      };
    }
  }
}
