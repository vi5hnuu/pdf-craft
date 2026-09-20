import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/tools/tool_registry.dart';
import 'package:pdf_craft/widgets/tool_picker_sheet.dart';

/// Offers the tools that can be applied to a file the user is already looking at.
///
/// Finishing a tool used to be a dead end: the result was saved, and running a second tool on it
/// meant leaving the screen, opening the file browser and finding the output again by name. The
/// registry already knows which tools accept which file types, and [ToolDef.openWithFiles] already
/// launches one with a file in hand — this just puts that within reach of the result itself.
class NextToolSheet {
  NextToolSheet._();

  /// Presents the shared tool picker for [file].
  ///
  /// This used to be its own flat, unsearchable list — one of four such implementations. The
  /// picker it now delegates to has search, category grouping and favourites/recents, which
  /// matters because a single PDF matches 47 of the 61 tools.
  static Future<void> show(BuildContext context, File file) {
    return ToolPickerSheet.show(
      context,
      files: [file],
      subtitle: file.path.split('/').last,
      onSelected: (tool) => unawaited(tool.openWithFiles(context, [file])),
    );
  }
}
