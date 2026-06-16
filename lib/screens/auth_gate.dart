import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shelf_snap/screens/home_screen.dart';
import 'package:shelf_snap/screens/login_screen.dart';
import 'package:shelf_snap/services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder<User?> rebuilds its builder every time the stream emits a new value
    // i.e. every login/logout.
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // snapshot.connectionState tells you whether the stream has emitted its first value yet.
        // On app startup there's a brief moment before Firebase reports the auth state —
        // showing a spinner avoids a flash of the wrong screen.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: CircularProgressIndicator());
        }

        // snapshot.data is the User? — if non-null, they're logged in.
        if (snapshot.hasData) {
          return HomeScreen();
        }

        return LoginScreen();
      },
    );
  }
}
