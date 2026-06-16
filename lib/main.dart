import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  // Flutter needs its internal "engine binding" set up before any platform-specific code (like Firebase, which talks to native Android/iOS code) can run.
  // Normally runApp() does this for you automatically, but since we're doing async work before runApp(), we have to call this manually first.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // Firebase.initializeApp() connects your app to your Firebase project (the one you created with flutterfire configure).
  // DefaultFirebaseOptions.currentPlatform automatically picks the right config — Android config when running on Android,
  // iOS config on iOS, etc. — from the generated firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShelfSnap',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}