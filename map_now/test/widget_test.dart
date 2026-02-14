import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_now/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts with Splash Screen', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that Splash Screen appears (checking for 'AmphereAI' text)
    expect(find.text('AmphereAI'), findsOneWidget);
    
    // Find the logo image container. 
    // It's decorated with a green circle color: Color(0xFFB1FF8E) = 4289855374 in decimal
    final Finder containerFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final decoration = widget.decoration as BoxDecoration;
        return decoration.color == const Color(0xFFB1FF8E) && decoration.shape == BoxShape.circle;
      }
      return false;
    });

    expect(containerFinder, findsOneWidget);
    
    // Resolve proper timers to avoid "Pending Timer" error
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
