import 'auth_api.dart';
import 'auth_failure.dart';
import 'session.dart';

/// Backend-free authentication for the app's local demo experience.
final class MockAuthApi implements AuthApi {
  MockAuthApi({this.latency = Duration.zero});

  static const demoEmail = 'demo@example.com';
  static const demoPassword = 'password123';
  static const demoOtpCode = '123456';
  static const _demoUserId = 'demo-user';

  final Duration latency;
  final Set<String> _otpRequestedEmails = {};
  Session? _currentSession;

  @override
  Session? get currentSession => _currentSession;

  @override
  Future<Session> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _wait();
    if (!_isDemoEmail(email) || password != demoPassword) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    return _startSession();
  }

  @override
  Future<void> requestEmailOtp({required String email}) async {
    await _wait();
    if (!_isDemoEmail(email)) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _otpRequestedEmails.add(_normalizeEmail(email));
  }

  @override
  Future<Session> signInWithEmailOtp({
    required String email,
    required String code,
  }) async {
    await _wait();
    final normalizedEmail = _normalizeEmail(email);
    if (!_otpRequestedEmails.remove(normalizedEmail)) {
      throw const AuthFailure(AuthFailureReason.otpNotRequested);
    }
    if (!_isDemoEmail(email) || code != demoOtpCode) {
      throw const AuthFailure(AuthFailureReason.invalidOtp);
    }
    return _startSession();
  }

  @override
  Future<void> signOut() async {
    await _wait();
    _currentSession = null;
  }

  Session _startSession() {
    return _currentSession = const Session(
      userId: _demoUserId,
      email: demoEmail,
    );
  }

  bool _isDemoEmail(String email) => _normalizeEmail(email) == demoEmail;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }
}
