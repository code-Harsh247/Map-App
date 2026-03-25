import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  
  AuthProvider({AuthService? authService}) 
      : _authService = authService ?? AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _token;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  String? get token => _token;

  Future<bool> login(String name, String mobile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(name, mobile);
      
      if (result['success']) {
        _currentUser = UserModel(name: name, mobile: mobile);
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        await prefs.setString('user_mobile', mobile);
        
        // Generate a mock token for demo purposes
        _token = 'demo_token_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('auth_token', _token!);
        
        // Set success message based on login source
        if (result['source'] == 'demo') {
          _errorMessage = 'Connected in demo mode - API unavailable';
        } else {
          _errorMessage = null; // Clear any previous error
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final mobile = prefs.getString('user_mobile');
    final savedToken = prefs.getString('auth_token');

    if (name != null && mobile != null) {
      _currentUser = UserModel(name: name, mobile: mobile);
      _token = savedToken;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_mobile');
    await prefs.remove('auth_token');
    _currentUser = null;
    _token = null;
    notifyListeners();
  }

  /// Ensures a valid token exists, generating one if needed
  Future<String?> ensureToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }

    if (isAuthenticated) {
      // Generate a new token
      _token = 'demo_token_${DateTime.now().millisecondsSinceEpoch}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      return _token;
    }

    return null;
  }
}
