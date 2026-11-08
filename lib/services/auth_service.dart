import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthOutcome {
  const AuthOutcome(this.ok, this.message);
  final bool ok;
  final String message;
}

/// Parent authentication (Supabase Auth). Children never need an account.
class AuthService {
  SupabaseClient? get _c => SupabaseService.client;
  User? get currentUser => _c?.auth.currentUser;

  Future<AuthOutcome> signIn(String email, String password) => _run(() async {
        await _c!.auth
            .signInWithPassword(email: email.trim(), password: password);
        return const AuthOutcome(true, 'Welcome back!');
      });

  Future<AuthOutcome> signUp(String email, String password) => _run(() async {
        final r =
            await _c!.auth.signUp(email: email.trim(), password: password);
        if (r.session == null) {
          return const AuthOutcome(true,
              'Almost there! Check your email to confirm your account, then sign in.');
        }
        return const AuthOutcome(true, 'Parent account created.');
      });

  Future<AuthOutcome> resetPassword(String email) => _run(() async {
        await _c!.auth.resetPasswordForEmail(email.trim());
        return const AuthOutcome(
            true, 'If that email has an account, a reset link is on its way.');
      });

  Future<void> signOut() async => _c?.auth.signOut();

  Future<AuthOutcome> _run(Future<AuthOutcome> Function() body) async {
    if (_c == null) {
      return const AuthOutcome(false,
          'Cloud is not set up in this build. See docs/SUPABASE_SETUP.md.');
    }
    try {
      return await body();
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.statusCode}');
      final m = e.message.toLowerCase();
      if (m.contains('invalid login'))
        return const AuthOutcome(false, 'That email or password is not right.');
      if (m.contains('already registered'))
        return const AuthOutcome(
            false, 'That email already has an account. Try signing in.');
      if (m.contains('password'))
        return const AuthOutcome(
            false, 'Please use a stronger password (at least 6 characters).');
      if (m.contains('email'))
        return const AuthOutcome(false, 'Please check the email address.');
      return const AuthOutcome(
          false, 'Could not sign in right now. Please try again.');
    } catch (e) {
      debugPrint('Auth failure: ${e.runtimeType}');
      return const AuthOutcome(
          false, 'Could not reach the cloud. Check your internet connection.');
    }
  }
}
