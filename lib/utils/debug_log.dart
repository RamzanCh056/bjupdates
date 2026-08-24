import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void logDebugException(
  String context,
  Object error, {
  StackTrace? stackTrace,
}) {
  developer.log(
    context,
    name: 'BeatJerky',
    error: error,
    stackTrace: stackTrace,
  );

  if (kDebugMode) {
    debugPrint('[$context] $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
