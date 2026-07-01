import 'dart:convert';
import 'package:dio/dio.dart';

/// One field to add to the PDF. Coordinates are in PDF points with a TOP-LEFT
/// origin (the backend flips Y). [type] is one of: text, multiline, checkbox,
/// radio, dropdown, date, signature.
class FormFieldSpec {
  final String type;
  final String name;
  final int page; // 0-indexed
  final double x, y, width, height;
  final String? value;
  final List<String>? options; // dropdown
  final String? exportValue;   // radio option value
  final double? fontSize;
  final bool? required;

  FormFieldSpec({
    required this.type,
    required this.name,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.value,
    this.options,
    this.exportValue,
    this.fontSize,
    this.required,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'page': page,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        if (value != null) 'value': value,
        if (options != null) 'options': options,
        if (exportValue != null) 'export_value': exportValue,
        if (fontSize != null) 'font_size': fontSize,
        if (required != null) 'required': required,
      };
}

class CreateForm {
  final String? outFileName;
  final List<FormFieldSpec> fields;
  final MultipartFile file;

  CreateForm({this.outFileName, required this.fields, required this.file});

  Map<String, dynamic> toJson() => {
        'create-form-info': MultipartFile.fromString(
          jsonEncode({
            if (outFileName != null) 'out_file_name': outFileName,
            'fields': fields.map((f) => f.toJson()).toList(),
          }),
          contentType: DioMediaType.parse('application/json'),
        ),
        'file': file,
      };
}
