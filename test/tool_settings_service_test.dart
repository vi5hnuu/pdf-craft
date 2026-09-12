import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/singletons/ToolSettingsService.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ToolSettingsService', () {
    test('has nothing to give before anything is saved', () async {
      expect(await ToolSettingsService().load('watermark'), isEmpty);
    });

    test('round-trips what was saved', () async {
      await ToolSettingsService().save('watermark', {'text': 'DRAFT', 'opacity': 0.4});
      expect(await ToolSettingsService().load('watermark'),
          {'text': 'DRAFT', 'opacity': 0.4});
    });

    test('keeps tools apart', () async {
      await ToolSettingsService().save('watermark', {'text': 'DRAFT'});
      expect(await ToolSettingsService().load('header-footer'), isEmpty);
    });

    test('forgets a tool on clear', () async {
      await ToolSettingsService().save('watermark', {'text': 'DRAFT'});
      await ToolSettingsService().clear('watermark');
      expect(await ToolSettingsService().load('watermark'), isEmpty);
    });

    test('discards a payload stored under an older shape', () async {
      SharedPreferences.setMockInitialValues({
        'tool_settings_watermark': '{"version":0,"values":{"text":"DRAFT"}}',
      });
      expect(await ToolSettingsService().load('watermark'), isEmpty);
    });

    test('survives corrupt JSON rather than failing the screen', () async {
      SharedPreferences.setMockInitialValues({'tool_settings_watermark': 'not json'});
      expect(await ToolSettingsService().load('watermark'), isEmpty);
    });

    test('read falls back when a key is missing or the wrong type', () {
      final values = {'text': 'DRAFT', 'fontSize': 'huge'};
      expect(ToolSettingsService.read(values, 'text', 'CONFIDENTIAL'), 'DRAFT');
      expect(ToolSettingsService.read(values, 'fontSize', 48), 48);
      expect(ToolSettingsService.read(values, 'missing', 12), 12);
    });

    test('read widens a whole number back to the double a slider needs', () {
      // JSON gives back an int for 1.0, which is the usual way a remembered slider
      // position comes back unusable.
      expect(ToolSettingsService.read(<String, dynamic>{'opacity': 1}, 'opacity', 0.3), 1.0);
    });
  });
}
