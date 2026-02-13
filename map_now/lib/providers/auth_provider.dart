import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

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

    if (name != null && mobile != null) {
      _currentUser = UserModel(name: name, mobile: mobile);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_mobile');
    _currentUser = null;
    notifyListeners();
  }
}
