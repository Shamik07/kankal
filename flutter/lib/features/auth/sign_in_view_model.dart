import 'package:stacked/stacked.dart';

import '../../core/auth/auth_api.dart';
import '../../core/auth/auth_failure.dart';
import '../../core/diagnostics/diagnostics.dart';

enum SignInMethod { password, emailOtp }

class SignInViewModel extends BaseViewModel {
  SignInViewModel(this._authApi, this._diagnostics);

  final AuthApi _authApi;
  final Diagnostics _diagnostics;
  SignInMethod method = SignInMethod.password;
  bool otpRequested = false;
  String? errorMessage;
  String? successMessage;

  void selectMethod(SignInMethod value) {
    method = value;
    errorMessage = null;
    successMessage = null;
    otpRequested = false;
    notifyListeners();
  }

  Future<bool> signInWithPassword(String email, String password) async {
    errorMessage = null;
    successMessage = null;
    setBusy(true);
    try {
      await _authApi.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _diagnostics.record(DiagnosticEvent.authPasswordSucceeded);
      return true;
    } on AuthFailure {
      _diagnostics.record(DiagnosticEvent.authPasswordFailed);
      errorMessage = 'Those credentials did not match. Please try again.';
      return false;
    } catch (error, stackTrace) {
      _diagnostics.recordError(
        DiagnosticEvent.authPasswordFailed,
        error,
        stackTrace,
      );
      errorMessage = 'Sign-in failed. Please try again.';
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> requestOtp(String email) async {
    errorMessage = null;
    successMessage = null;
    setBusy(true);
    try {
      await _authApi.requestEmailOtp(email: email.trim());
      _diagnostics.record(DiagnosticEvent.authEmailOtpRequestSucceeded);
      otpRequested = true;
      successMessage = 'Sign-in code requested.';
      return true;
    } on AuthFailure {
      _diagnostics.record(DiagnosticEvent.authEmailOtpRequestFailed);
      errorMessage = 'Could not send a code to that email.';
      return false;
    } catch (error, stackTrace) {
      _diagnostics.recordError(
        DiagnosticEvent.authEmailOtpRequestFailed,
        error,
        stackTrace,
      );
      errorMessage = 'Could not request a code. Please try again.';
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> signInWithOtp(String email, String code) async {
    errorMessage = null;
    successMessage = null;
    setBusy(true);
    try {
      await _authApi.signInWithEmailOtp(email: email.trim(), code: code.trim());
      _diagnostics.record(DiagnosticEvent.authEmailOtpSucceeded);
      return true;
    } on AuthFailure {
      _diagnostics.record(DiagnosticEvent.authEmailOtpFailed);
      errorMessage = 'That code is invalid or has expired.';
      return false;
    } catch (error, stackTrace) {
      _diagnostics.recordError(
        DiagnosticEvent.authEmailOtpFailed,
        error,
        stackTrace,
      );
      errorMessage = 'Sign-in failed. Please try again.';
      return false;
    } finally {
      setBusy(false);
    }
  }
}
