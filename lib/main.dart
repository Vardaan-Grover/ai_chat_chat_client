import 'package:ai_chat_chat_client/views/screens/about_screen.dart';
import 'package:ai_chat_chat_client/views/screens/chat_screen.dart';
import 'package:ai_chat_chat_client/views/screens/home_screen.dart';
import 'package:ai_chat_chat_client/views/screens/language_screen.dart';
import 'package:ai_chat_chat_client/views/screens/login_screen.dart';
import 'package:ai_chat_chat_client/views/screens/profile_screen.dart';
import 'package:ai_chat_chat_client/views/screens/search_screen.dart';
import 'package:ai_chat_chat_client/views/screens/setting_screen.dart';
import 'package:flutter/material.dart';
import 'views/screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'chat_chat_ai',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SearchScreen(), // <- Show SplashScreen instead of MyHomePage
    );
  }
}
