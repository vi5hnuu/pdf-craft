import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';

/// Holds files shared or opened into the app until there is somewhere to show them.
///
/// Exists because of a race that silently ate every cold-start share. The share handler used to
/// push `/incoming-files` as soon as the native side delivered the paths — within the first
/// frame or two. The splash screen then finishes at 500ms and calls `go`, which **replaces** the
/// navigation stack, taking the just-pushed chooser with it. The file was gone and the user
/// landed on the normal home screen with no indication anything had been shared. Warm starts
/// were fine, because no splash runs.
///
/// So the files are parked here instead, and whoever owns the first destination drains them:
/// the splash on a normal launch, the onboarding screen when a brand-new user shares something
/// before they have ever opened the app. Once the app is past startup, [ready] is true and the
/// handler navigates immediately, which is the path that always worked.
class PendingIncomingFiles {
  PendingIncomingFiles._();

  static final List<File> _files = [];

  /// True once the app is past the splash, so a navigation will not be replaced out from under
  /// us and incoming files can be routed the moment they arrive.
  static bool ready = false;

  static bool get isEmpty => _files.isEmpty;
  static bool get isNotEmpty => _files.isNotEmpty;

  static void add(Iterable<File> files) => _files.addAll(files);

  /// Returns everything held and clears the queue.
  static List<File> take() {
    final out = List<File>.from(_files);
    _files.clear();
    return out;
  }

  /// Routes to the chooser if anything is waiting, on top of the home screen so Back has
  /// somewhere to go. Safe to call when the queue is empty — it does nothing.
  ///
  /// The caller must already have navigated to the destination it wants underneath.
  static void drain(BuildContext context) {
    if (_files.isEmpty) return;
    GoRouter.of(context)
        .pushNamed(AppRoutes.incomingFilesRoute.name, extra: take());
  }
}
