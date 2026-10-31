enum AuthFailureReason { invalidCredentials, otpNotRequested, invalidOtp }

final class AuthFailure implements Exception {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure: $reason';
}
