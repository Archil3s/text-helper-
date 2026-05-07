import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:text_helper/screens/home_screen.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('Home screen matches iPhone 13 viewport', (tester) async {
    const iphone13Viewport = Size(390, 844);

    await tester.binding.setSurfaceSize(iphone13Viewport);
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        title: 'Text Helper',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0A84FF),
          brightness: Brightness.light,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        ),
        home: const HomeScreen(),
      ),
    );

    await tester.pumpAndSettle();

    await screenMatchesGolden(
      tester,
      'home_screen_iphone13',
    );
  });
}
