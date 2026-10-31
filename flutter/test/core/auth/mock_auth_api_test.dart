import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/core/auth/auth_failure.dart';
import 'package:flutter_kankal/core/auth/mock_auth_api.dart';

void main() {
  group('MockAuthApi', () {
    test('password and OTP sign-in produce the same demo session', () async {
      final passwordApi = MockAuthApi();
      final passwordSession = await passwordApi.signInWithPassword(
        email: MockAuthApi.demoEmail,
        password: MockAuthApi.demoPassword,
      );

      final otpApi = MockAuthApi();
      await otpApi.requestEmailOtp(email: MockAuthApi.demoEmail);
      final otpSession = await otpApi.signInWithEmailOtp(
        email: MockAuthApi.demoEmail,
        code: MockAuthApi.demoOtpCode,
      );

      expect(otpSession.userId, passwordSession.userId);
      expect(otpSession.email, passwordSession.email);
      expect(passwordApi.currentSession, passwordSession);
      expect(otpApi.currentSession, otpSession);
    });

    test(
      'rejects wrong password asynchronously and remains signed out',
      () async {
        final api = MockAuthApi(latency: const Duration(milliseconds: 1));

        await expectLater(
          api.signInWithPassword(
            email: MockAuthApi.demoEmail,
            password: 'wrong',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (failure) => failure.reason,
              'reason',
              AuthFailureReason.invalidCredentials,
            ),
          ),
        );
        expect(api.currentSession, isNull);
      },
    );

    test('OTP must be requested, and sign-out clears the session', () async {
      final api = MockAuthApi();
      await expectLater(
        api.signInWithEmailOtp(
          email: MockAuthApi.demoEmail,
          code: MockAuthApi.demoOtpCode,
        ),
        throwsA(isA<AuthFailure>()),
      );

      await api.signInWithPassword(
        email: MockAuthApi.demoEmail,
        password: MockAuthApi.demoPassword,
      );
      await api.signOut();
      expect(api.currentSession, isNull);
    });
  });
}
