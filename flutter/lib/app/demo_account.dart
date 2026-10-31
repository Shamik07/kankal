import '../core/auth/mock_auth_api.dart';

class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.code,
  });

  static const defaults = DemoAccount(
    email: MockAuthApi.demoEmail,
    password: MockAuthApi.demoPassword,
    code: MockAuthApi.demoOtpCode,
  );

  final String email;
  final String password;
  final String code;
}
