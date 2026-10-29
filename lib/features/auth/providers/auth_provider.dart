import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';

// The signed-in user's uid; null when signed out
final currentUidProvider = StreamProvider<String?>(
  (ref) => AuthService().authStateChanges.map((user) => user?.uid),
);
