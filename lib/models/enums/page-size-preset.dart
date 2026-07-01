enum PageSizePreset {
  a4,
  letter,
  legal;

  String get wire => switch (this) {
        PageSizePreset.a4 => 'A4',
        PageSizePreset.letter => 'LETTER',
        PageSizePreset.legal => 'LEGAL',
      };

  String get label => switch (this) {
        PageSizePreset.a4 => 'A4',
        PageSizePreset.letter => 'Letter',
        PageSizePreset.legal => 'Legal',
      };

  String get dimensions => switch (this) {
        PageSizePreset.a4 => '210 × 297 mm',
        PageSizePreset.letter => '8.5 × 11 in',
        PageSizePreset.legal => '8.5 × 14 in',
      };
}
