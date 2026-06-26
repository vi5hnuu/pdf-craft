import 'dart:async';
import 'package:flutter/foundation.dart';

/// A small reusable debouncer.
///
/// Collapses a burst of rapid calls into a single trailing call that fires only
/// after [delay] of silence. Use it for search boxes, filter fields, and any
/// input that would otherwise trigger expensive work (disk scans, API calls) on
/// every keystroke.
///
/// Example:
/// ```dart
/// final _debouncer = Debouncer(milliseconds: 300);
/// onChanged: (q) => _debouncer.run(() => _search(q));
/// ```
/// Remember to call [dispose] (e.g. in `State.dispose`) to cancel any pending
/// timer and avoid callbacks firing after the widget is gone.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({int milliseconds = 300})
      : delay = Duration(milliseconds: milliseconds);

  /// Schedules [action], cancelling any previously scheduled (not-yet-fired) one.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// True while a call is scheduled but has not yet fired.
  bool get isActive => _timer?.isActive ?? false;

  /// Cancels any pending call without firing it.
  void cancel() => _timer?.cancel();

  /// Cancels the pending call and releases the timer. Call from `dispose`.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
