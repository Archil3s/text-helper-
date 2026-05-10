import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'screens/whatsapp_business_sender_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TextHelperApp());
}

class TextHelperApp extends StatelessWidget {
  const TextHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0A84FF),
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF2F2F7),
          foregroundColor: CupertinoColors.label,
        ),
      ),
      home: const WhatsAppBusinessSenderScreen(),
    );
  }
}
