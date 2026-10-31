import 'session.dart';

abstract interface class AuthApi {
  Session? get currentSession;

  Future<Session> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> requestEmailOtp({required String email});

  Future<Session> signInWithEmailOtp({
    required String email,
    required String code,
  });

  Future<void> signOut();
}
