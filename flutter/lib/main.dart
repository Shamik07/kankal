import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'core/diagnostics/diagnostics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics =
      kDebugMode ? const LocalDiagnostics() : const NoopDiagnostics();
  FlutterError.onError = (details) {
    diagnostics.recordError(
      DiagnosticEvent.appError,
      details.exception,
      details.stack ?? StackTrace.current,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    diagnostics.recordError(DiagnosticEvent.appError, error, stack);
    return false;
  };
  runApp(const KankalApp());
}
