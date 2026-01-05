import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRepository {
  // In a real app, this would interact with Firebase or an API
  Future<void> signIn(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    if (email == 'user@example.com' && password == 'password') {
       return;
    }
    // For demo purposes, we'll allow any login
    return;
  }

  Future<void> signUp(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    return;
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  Stream<String?> get authStateChanges => Stream.value('mock_user_id'); // Always logged in for demo after login
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
