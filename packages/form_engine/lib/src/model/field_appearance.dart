/// How a widget looks, and how it behaves beyond its value.
///
/// These are nested objects rather than more flat fields on [FormFieldModel] for the same
/// reason [FieldValidation] is: the model already carries fifteen loose properties, and adding
/// another eighteen would make every constructor call unreadable. Both omit themselves from
/// storage when they hold nothing but defaults, so a draft of ordinary fields is unchanged.
library;

/// Line style for a widget's border, mirroring the PDF border-style names.
enum BorderStyleName {
  solid,
  dashed,
  beveled,
  inset,
  underline;

  static BorderStyleName fromWire(String? name) => BorderStyleName.values
      .firstWhere((s) => s.name == name, orElse: () => BorderStyleName.solid);
}

/// Font families available to a field, limited to the faces the API can embed.
enum FieldFontFamily {
  helvetica,
  times,
  courier;

  static FieldFontFamily fromWire(String? name) => FieldFontFamily.values
      .firstWhere((f) => f.name == name, orElse: () => FieldFontFamily.helvetica);
}

/// Border, background, text colour and rotation for one widget.
///
/// Every widget used to be 1pt solid grey on a 0.96 grey fill in black Helvetica, hardcoded in
/// the API, while the editor's canvas painter already previewed styling the output could not
/// carry.
class FieldAppearance {
  /// #RRGGBB, or null for the API's readable default.
  final String? borderColor;

  /// #RRGGBB, or null for the default tint. Empty string means a transparent box, which a form
  /// printed over existing ruled lines needs.
  final String? backgroundColor;

  final String? textColor;

  /// Border width in points. 0 removes the border.
  final double? borderWidth;

  final BorderStyleName borderStyle;
  final FieldFontFamily fontFamily;

  /// Widget rotation in degrees: 0, 90, 180 or 270.
  final int rotation;

  const FieldAppearance({
    this.borderColor,
    this.backgroundColor,
    this.textColor,
    this.borderWidth,
    this.borderStyle = BorderStyleName.solid,
    this.fontFamily = FieldFontFamily.helvetica,
    this.rotation = 0,
  });

  bool get isDefault =>
      borderColor == null &&
      backgroundColor == null &&
      textColor == null &&
      borderWidth == null &&
      borderStyle == BorderStyleName.solid &&
      fontFamily == FieldFontFamily.helvetica &&
      rotation == 0;

  FieldAppearance copyWith({
    String? borderColor,
    String? backgroundColor,
    String? textColor,
    double? borderWidth,
    BorderStyleName? borderStyle,
    FieldFontFamily? fontFamily,
    int? rotation,
  }) =>
      FieldAppearance(
        borderColor: borderColor ?? this.borderColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        textColor: textColor ?? this.textColor,
        borderWidth: borderWidth ?? this.borderWidth,
        borderStyle: borderStyle ?? this.borderStyle,
        fontFamily: fontFamily ?? this.fontFamily,
        rotation: rotation ?? this.rotation,
      );

  Map<String, Object?> toJson() => {
        if (borderColor != null) 'border_color': borderColor,
        if (backgroundColor != null) 'background_color': backgroundColor,
        if (textColor != null) 'text_color': textColor,
        if (borderWidth != null) 'border_width': borderWidth,
        if (borderStyle != BorderStyleName.solid) 'border_style': borderStyle.name,
        if (fontFamily != FieldFontFamily.helvetica) 'font_family': fontFamily.name,
        if (rotation != 0) 'rotation': rotation,
      };

  static FieldAppearance fromJson(Map<String, Object?> json) => FieldAppearance(
        borderColor: json['border_color'] as String?,
        backgroundColor: json['background_color'] as String?,
        textColor: json['text_color'] as String?,
        borderWidth: (json['border_width'] as num?)?.toDouble(),
        borderStyle: BorderStyleName.fromWire(json['border_style'] as String?),
        fontFamily: FieldFontFamily.fromWire(json['font_family'] as String?),
        rotation: (json['rotation'] as num?)?.toInt() ?? 0,
      );
}

/// Flags that change how a field behaves without changing its value.
class FieldBehaviour {
  /// Kept out of an exported data set (/Ff bit 3).
  final bool noExport;

  /// Text masked as it is typed.
  final bool password;

  final bool doNotSpellCheck;

  /// Refuse input past the visible box rather than scrolling it.
  final bool doNotScroll;

  /// A dropdown the filler may type into instead of being held to the options.
  final bool editable;

  /// The reader presents the options sorted.
  final bool sortOptions;

  /// Neither shown nor printed.
  final bool hidden;

  /// On screen but never printed. Impossible before, because the API forced
  /// setPrinted(true) on every widget.
  final bool noPrint;

  const FieldBehaviour({
    this.noExport = false,
    this.password = false,
    this.doNotSpellCheck = false,
    this.doNotScroll = false,
    this.editable = false,
    this.sortOptions = false,
    this.hidden = false,
    this.noPrint = false,
  });

  bool get isDefault =>
      !noExport &&
      !password &&
      !doNotSpellCheck &&
      !doNotScroll &&
      !editable &&
      !sortOptions &&
      !hidden &&
      !noPrint;

  FieldBehaviour copyWith({
    bool? noExport,
    bool? password,
    bool? doNotSpellCheck,
    bool? doNotScroll,
    bool? editable,
    bool? sortOptions,
    bool? hidden,
    bool? noPrint,
  }) =>
      FieldBehaviour(
        noExport: noExport ?? this.noExport,
        password: password ?? this.password,
        doNotSpellCheck: doNotSpellCheck ?? this.doNotSpellCheck,
        doNotScroll: doNotScroll ?? this.doNotScroll,
        editable: editable ?? this.editable,
        sortOptions: sortOptions ?? this.sortOptions,
        hidden: hidden ?? this.hidden,
        noPrint: noPrint ?? this.noPrint,
      );

  Map<String, Object?> toJson() => {
        if (noExport) 'no_export': true,
        if (password) 'password': true,
        if (doNotSpellCheck) 'do_not_spell_check': true,
        if (doNotScroll) 'do_not_scroll': true,
        if (editable) 'editable': true,
        if (sortOptions) 'sort_options': true,
        if (hidden) 'hidden': true,
        if (noPrint) 'no_print': true,
      };

  static FieldBehaviour fromJson(Map<String, Object?> json) => FieldBehaviour(
        noExport: json['no_export'] as bool? ?? false,
        password: json['password'] as bool? ?? false,
        doNotSpellCheck: json['do_not_spell_check'] as bool? ?? false,
        doNotScroll: json['do_not_scroll'] as bool? ?? false,
        editable: json['editable'] as bool? ?? false,
        sortOptions: json['sort_options'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        noPrint: json['no_print'] as bool? ?? false,
      );
}
