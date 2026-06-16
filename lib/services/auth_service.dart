import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Stream that emits whenever the user logs in or out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 2. Get the current logged-in user (or null)
  User? get currentUser => _auth.currentUser;

  // 3. Sign up with email & password
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Rethrow so the UI layer (signup screen) can catch it and show a message
      rethrow;
    }
  }

  // 4. Sign in with email & password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  // 5. Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
