import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// The small, privacy-safe set of events the app may record.
///
/// Events intentionally carry no properties. In particular, callers cannot
/// attach credentials, contact details, request data, or arbitrary values.
enum DiagnosticEvent {
  authPasswordSucceeded,
  authPasswordFailed,
  authEmailOtpRequestSucceeded,
  authEmailOtpRequestFailed,
  authEmailOtpSucceeded,
  authEmailOtpFailed,
  authSignOutSucceeded,
  authSignOutFailed,
  itemCreateSucceeded,
  itemCreateFailed,
  itemReadSucceeded,
  itemReadFailed,
  itemUpdateSucceeded,
  itemUpdateFailed,
  itemDeleteSucceeded,
  itemDeleteFailed,
  appError,
}

/// Replaceable boundary for local diagnostics and a future analytics adapter.
abstract interface class Diagnostics {
  void record(DiagnosticEvent event);

  void recordError(DiagnosticEvent event, Object error, StackTrace stackTrace);
}

/// Records event names locally in debug builds and does nothing in release.
final class LocalDiagnostics implements Diagnostics {
  const LocalDiagnostics();

  @override
  void record(DiagnosticEvent event) {
    if (kDebugMode) {
      developer.log(
        event.name,
        name: _categoryFor(event),
        level: _levelFor(event),
      );
    }
  }

  @override
  void recordError(DiagnosticEvent event, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      developer.log(
        '${event.name}: ${error.runtimeType}',
        name: _categoryFor(event),
        level: _levelFor(event),
        stackTrace: stackTrace,
      );
    }
  }

  String _categoryFor(DiagnosticEvent event) => switch (event) {
    DiagnosticEvent.authPasswordSucceeded ||
    DiagnosticEvent.authPasswordFailed ||
    DiagnosticEvent.authEmailOtpRequestSucceeded ||
    DiagnosticEvent.authEmailOtpRequestFailed ||
    DiagnosticEvent.authEmailOtpSucceeded ||
    DiagnosticEvent.authEmailOtpFailed ||
    DiagnosticEvent.authSignOutSucceeded ||
    DiagnosticEvent.authSignOutFailed => 'kankal.auth',
    DiagnosticEvent.itemCreateSucceeded ||
    DiagnosticEvent.itemCreateFailed ||
    DiagnosticEvent.itemReadSucceeded ||
    DiagnosticEvent.itemReadFailed ||
    DiagnosticEvent.itemUpdateSucceeded ||
    DiagnosticEvent.itemUpdateFailed ||
    DiagnosticEvent.itemDeleteSucceeded ||
    DiagnosticEvent.itemDeleteFailed => 'kankal.items',
    DiagnosticEvent.appError => 'kankal.app',
  };

  int _levelFor(DiagnosticEvent event) => switch (event) {
    DiagnosticEvent.authPasswordSucceeded ||
    DiagnosticEvent.authEmailOtpRequestSucceeded ||
    DiagnosticEvent.authEmailOtpSucceeded ||
    DiagnosticEvent.authSignOutSucceeded ||
    DiagnosticEvent.itemCreateSucceeded ||
    DiagnosticEvent.itemReadSucceeded ||
    DiagnosticEvent.itemUpdateSucceeded ||
    DiagnosticEvent.itemDeleteSucceeded => 800,
    DiagnosticEvent.appError => 1000,
    _ => 900,
  };
}

/// A no-op implementation for callers that need diagnostics disabled.
final class NoopDiagnostics implements Diagnostics {
  const NoopDiagnostics();

  @override
  void record(DiagnosticEvent event) {}

  @override
  void recordError(
    DiagnosticEvent event,
    Object error,
    StackTrace stackTrace,
  ) {}
}
