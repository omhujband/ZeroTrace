import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secure_wipe_app/main.dart';
import 'package:secure_wipe_app/providers/theme_provider.dart';

void main() {
  testWidgets('App should load home screen', (WidgetTester tester) async {
    // Create theme provider for testing
    final themeProvider = ThemeProvider();

    // Build our app and trigger a frame
    await tester.pumpWidget(ZeroTraceApp(themeProvider: themeProvider));

    // Verify app loads with title
    expect(find.text('ZeroTrace'), findsOneWidget);
  });
}
