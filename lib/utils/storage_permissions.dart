import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissions {
  /// Android SDK level, cached. It cannot change while the app runs, and the router's global
  /// redirect asks for permission state on every navigation — querying DeviceInfoPlugin each
  /// time was pure overhead.
  static int? _sdkInt;

  static Future<int> _sdk() async =>
      _sdkInt ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  static Future<bool> requestStoragePermissions() async {
    if (await isStoragePermissionGranted()) return true;

    if (await _sdk() >= 33) {
      final re = await Permission.manageExternalStorage.request();
      return re.isGranted;
    } else {
      final res = await Permission.storage.request();
      return res.isGranted;
    }
  }

  static Future<bool> isStoragePermissionGranted() async {
    if (await _sdk() >= 33) {
      return await Permission.manageExternalStorage.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }

  /// True when the OS will no longer show the request dialog, so the only way to
  /// grant is via system Settings.
  static Future<bool> isPermanentlyDenied() async {
    if (await _sdk() >= 33) {
      return await Permission.manageExternalStorage.isPermanentlyDenied;
    } else {
      return await Permission.storage.isPermanentlyDenied;
    }
  }
}
