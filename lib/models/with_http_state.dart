import 'package:pdf_craft/models/http_state.dart';

/// Per-key request state carried by a bloc state.
///
/// Trimmed to what is used. It previously carried isDone, anyLoading, anyError, getAnyError,
/// isError, hasHttpState and printStates as well — seven members with no callers anywhere,
/// which made the surface look like a general-purpose API when two accessors are what the
/// screens actually read.
mixin WithHttpState {
  final Map<String, HttpState> httpStates = {};

  bool isLoading({required final String forr}) {
    return httpStates.containsKey(forr) && httpStates[forr]!.loading;
  }

  String? getError({required final String forr}) {
    return httpStates[forr]?.error;
  }
}
