import 'package:flutter/widgets.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/enums/compression_level.dart';
import 'package:pdf_craft/models/enums/mirror_direction.dart';
import 'package:pdf_craft/models/enums/position.dart';

/// Localized labels for the model enums.
///
/// The enums themselves stay free of any BuildContext or localization
/// dependency: their `displayName` / `label` remain the English values used for
/// logs and wire formats, and only the UI reaches for these extensions.
extension CompressionLevelL10n on CompressionLevel {
  String localizedLabel(BuildContext context) => switch (this) {
        CompressionLevel.EXTREME => L10n.of(context).compressionExtreme,
        CompressionLevel.RECOMMENDED => L10n.of(context).compressionRecommended,
        CompressionLevel.LOW => L10n.of(context).compressionLow,
      };
}

extension WatermarkPositionL10n on WatermarkPosition {
  String localizedLabel(BuildContext context) => switch (this) {
        WatermarkPosition.START => L10n.of(context).positionStart,
        WatermarkPosition.CENTER => L10n.of(context).positionCenter,
        WatermarkPosition.END => L10n.of(context).positionEnd,
      };
}

extension MirrorDirectionL10n on MirrorDirection {
  String localizedLabel(BuildContext context) => this == MirrorDirection.horizontal
      ? L10n.of(context).horizontal
      : L10n.of(context).vertical;
}
