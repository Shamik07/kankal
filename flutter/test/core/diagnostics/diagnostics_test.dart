import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/core/diagnostics/diagnostics.dart';

void main() {
  test('recordError does not stringify the error', () {
    const diagnostics = LocalDiagnostics();

    expect(
      () => diagnostics.recordError(
        DiagnosticEvent.appError,
        _ErrorWithUnsafeToString(),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });
}

final class _ErrorWithUnsafeToString implements Exception {
  @override
  String toString() => throw StateError('must not stringify an error');
}
