import 'dart:convert';
import 'package:dio/dio.dart';

/// What to strip when sanitizing.
///
/// Every flag defaults to what sanitize always did, so the part is only sent when the user has
/// actually changed something — the backend treats an absent part as "all defaults".
class SanitizePdf {
  final MultipartFile file;
  final bool javaScript;
  final bool embeddedFiles;
  final bool actions;
  final bool metadata;
  final bool annotations;
  final bool externalLinks;
  final bool forms;

  SanitizePdf({
    required this.file,
    this.javaScript = true,
    this.embeddedFiles = true,
    this.actions = true,
    this.metadata = true,
    this.annotations = false,
    this.externalLinks = false,
    this.forms = false,
  });

  /// True when nothing would be removed — the screen refuses to send that rather than charging a
  /// round trip for a byte-identical copy.
  bool get isNoop =>
      !javaScript &&
      !embeddedFiles &&
      !actions &&
      !metadata &&
      !annotations &&
      !externalLinks &&
      !forms;

  Map<String, dynamic> toJson() => {
        'sanitize-pdf-info': MultipartFile.fromString(
          jsonEncode({
            'remove_java_script': javaScript,
            'remove_embedded_files': embeddedFiles,
            'remove_actions': actions,
            'remove_metadata': metadata,
            'remove_annotations': annotations,
            'remove_external_links': externalLinks,
            'remove_forms': forms,
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
