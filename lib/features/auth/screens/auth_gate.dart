import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/home/screens/home_screen.dart';
import 'package:shelf_snap/features/auth/screens/login_screen.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/profile/screens/choose_username_screen.dart';

// Picks the first screen: login, choose username, or home
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds on every sign in and sign out
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Firebase hasn't reported the auth state yet
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // Signed in, so check for a users/{uid} profile
        final profileAsync = ref.watch(userProfileProvider(user.uid));

        return profileAsync.when(
          data: (profile) => profile == null
              ? const ChooseUsernameScreen()
              : const HomeScreen(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => _ProfileError(error: err),
        );
      },
    );
  }
}

// Shown when the profile can't be read, with a way to sign out
class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Couldn't load your profile",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => AuthService().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
