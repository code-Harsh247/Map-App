import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_now/screens/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:map_now/providers/auth_provider.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helper.mocks.dart';

void main() {
  testWidgets('WelcomeScreen renders and finds widgets', (WidgetTester tester) async {
    final mockAuthService = MockAuthService();
    // SharedPreferences mock implicitly needed by AuthService? No, by AuthProvider constructor?
    // AuthProvider constructor doesn't access SharedPreferences.
    // However, WelcomeScreen might access SharedPreferences inside initState or methods.
    // _handleGetStarted -> setState.
    // _handleLogin -> uses SharedPreferences.
    
    // We should probably ensure SharedPreferences is mocked for the test environment.
    // SharedPreferences.setMockInitialValues({}); // This is needed often.
    
    final authProvider = AuthProvider(authService: mockAuthService);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );

    // Initial render checks
    expect(find.text('Navigate your world\nwith ease & confidence'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
  
  testWidgets('Clicking Get Started shows login panel', (WidgetTester tester) async {
    final mockAuthService = MockAuthService();
    final authProvider = AuthProvider(authService: mockAuthService);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );

    // Tap Get Started
    await tester.tap(find.text('Get Started'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Finish animation

    // Check if Login text appears (Title and Button)
    expect(find.text('Login'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
  });
}
