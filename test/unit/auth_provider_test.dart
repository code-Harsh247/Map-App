import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map_now/providers/auth_provider.dart';
import '../helpers/test_helper.mocks.dart';

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    // SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    authProvider = AuthProvider(authService: mockAuthService);
  });

  group('AuthProvider Tests', () {
    test('Initial state should be unauthenticated', () {
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, null);
      expect(authProvider.isLoading, false);
    });

    test('login success should update user and return true', () async {
      // Arrange
      const name = 'Test User';
      const mobile = '1234567890';
      
      when(mockAuthService.login(any, any))
          .thenAnswer((_) async => {
                'success': true,
                'data': {
                   'message': 'Login successful',
                   'user': {'name': name, 'mobile': mobile}
                }
              });

      // Act
      final result = await authProvider.login(name, mobile);

      // Assert
      expect(result, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.currentUser?.name, name);
      expect(authProvider.currentUser?.mobile, mobile);
      expect(authProvider.isLoading, false);
    });

    test('login failure should update errorMessage and return false', () async {
      // Arrange
      const name = 'Test User';
      const mobile = '000'; // Invalid
      
      when(mockAuthService.login(any, any))
          .thenAnswer((_) async => {
                'success': false,
                'error': 'Valid mobile number is required'
              });

      // Act
      final result = await authProvider.login(name, mobile);

      // Assert
      expect(result, false);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.errorMessage, 'Valid mobile number is required');
      expect(authProvider.isLoading, false);
    });

    test('loadUserFromStorage should restore user session', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_name': 'Saved User',
        'user_mobile': '9876543210'
      });
      
      // Re-initialize provider to read mock values (if it was reading in constructor, but it's not)
      // loadUserFromStorage is a method we need to call.
      
      // Act
      await authProvider.loadUserFromStorage();

      // Assert
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.currentUser?.name, 'Saved User');
    });

    test('logout should clear user and storage', () async {
       // Arrange
      SharedPreferences.setMockInitialValues({
        'user_name': 'Saved User',
        'user_mobile': '9876543210'
      });
      await authProvider.loadUserFromStorage();
      expect(authProvider.isAuthenticated, true);

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.currentUser, null);
      
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), null);
    });
  });
}
